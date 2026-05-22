-- ============================================================================
-- SQL Schema Setup & Realtime Configuration for Miriverbs
-- Executable in the Supabase SQL Editor
-- ============================================================================

-- Enable UUID extension if not already enabled
create extension if not exists "uuid-ossp";

-- ────────────────────────────────────────────────────────────────────────────
-- 1. PROFILES TABLE
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
    id uuid references auth.users on delete cascade primary key,
    full_name text,
    avatar_url text,
    push_token text,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS) for profiles
alter table public.profiles enable row level security;

-- Policies for profiles
create policy "Allow public read access to profiles" 
on public.profiles for select 
using (true);

create policy "Allow individual user to update their own profile" 
on public.profiles for update 
using (auth.uid() = id);

create policy "Allow individual user to insert their own profile" 
on public.profiles for insert 
with check (auth.uid() = id);

-- ────────────────────────────────────────────────────────────────────────────
-- 2. USER PRESENCE TABLE
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.user_presences (
    user_id uuid references public.profiles(id) on delete cascade primary key,
    is_online boolean default false not null,
    last_seen timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for user_presences
alter table public.user_presences enable row level security;

-- Policies for user_presences
create policy "Allow public read access to presences" 
on public.user_presences for select 
using (true);

create policy "Allow individual user to manage their own presence" 
on public.user_presences for all 
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────────────────────
-- 3. BATTLE SESSIONS TABLE
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.battle_sessions (
    id uuid default gen_random_uuid() primary key,
    challenger_id uuid references public.profiles(id) on delete cascade not null,
    challenged_id uuid references public.profiles(id) on delete cascade not null,
    status text default 'pending'::text not null, -- pending, active, finished, cancelled, abandoned
    word_seed integer not null,
    winner_id uuid references public.profiles(id) on delete set null,
    abandoned_by uuid references public.profiles(id) on delete set null,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for battle_sessions
alter table public.battle_sessions enable row level security;

-- Policies for battle_sessions
create policy "Allow players to read their own battle sessions" 
on public.battle_sessions for select 
using (auth.uid() = challenger_id or auth.uid() = challenged_id);

create policy "Allow player to insert their own challenge" 
on public.battle_sessions for insert 
with check (auth.uid() = challenger_id);

create policy "Allow players to update their battle sessions" 
on public.battle_sessions for update 
using (auth.uid() = challenger_id or auth.uid() = challenged_id);

-- ────────────────────────────────────────────────────────────────────────────
-- 4. BATTLE RESULTS TABLE
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.battle_results (
    session_id uuid references public.battle_sessions(id) on delete cascade not null,
    user_id uuid references public.profiles(id) on delete cascade not null,
    score integer default 0 not null,
    errors integer default 0 not null,
    time_taken_ms integer default 0 not null,
    completed_at timestamp with time zone default timezone('utc'::text, now()) not null,
    primary key (session_id, user_id)
);

-- Enable RLS for battle_results
alter table public.battle_results enable row level security;

-- Policies for battle_results
create policy "Allow players to view results of a session they participated in" 
on public.battle_results for select 
using (
    exists (
        select 1 from public.battle_sessions
        where id = session_id 
        and (challenger_id = auth.uid() or challenged_id = auth.uid())
    )
);

create policy "Allow player to submit their own result" 
on public.battle_results for insert 
with check (auth.uid() = user_id);

create policy "Allow player to update their own result" 
on public.battle_results for update 
using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────────────────────
-- 5. BATTLE STATS TABLE
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.battle_stats (
    user_id uuid references public.profiles(id) on delete cascade primary key,
    wins integer default 0 not null,
    losses integer default 0 not null,
    ties integer default 0 not null,
    abandons integer default 0 not null,
    total_games integer default 0 not null
);

-- Enable RLS for battle_stats
alter table public.battle_stats enable row level security;

-- Policies for battle_stats
create policy "Allow public read access to battle stats" 
on public.battle_stats for select 
using (true);

create policy "Allow players to manage their own battle stats" 
on public.battle_stats for all 
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────────────────────
-- 6. VERBS TABLE (SYLLABUS DATA FOR SEEDING)
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.verbs (
    id serial primary key,
    infinitive text not null unique,
    spanish text not null,
    past_simple text not null,
    past_participle text not null,
    gerund text not null,
    example_en text not null,
    example_es text not null,
    difficulty text not null -- basic, intermediate, advanced
);

-- Enable RLS for verbs
alter table public.verbs enable row level security;

-- Policies for verbs
create policy "Allow public read access to verbs syllabus"
on public.verbs for select
using (true);

-- ────────────────────────────────────────────────────────────────────────────
-- 7. PROFILE & PRESENCE AUTO-GENERATION ON SIGN UP
-- ────────────────────────────────────────────────────────────────────────────
-- This function automatically creates a profile and presence entry when a user signs up.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture', '')
  );

  insert into public.user_presences (user_id, is_online, last_seen)
  values (new.id, false, now());

  insert into public.battle_stats (user_id, wins, losses, ties, abandons, total_games)
  values (new.id, 0, 0, 0, 0, 0);

  return new;
end;
$$ language plpgsql security definer;

-- Trigger to execute on signup
create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ────────────────────────────────────────────────────────────────────────────
-- 8. ENABLE REALTIME REPLICATION FOR ACTIVE SYNC
-- ────────────────────────────────────────────────────────────────────────────
-- Make sure the battle_sessions and user_presences tables publish changes in real-time
do $$
begin
  -- Check if publication exists, otherwise create it
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

-- Add tables to publication (ignoring errors if already added)
begin;
  -- In case they are already added, we drop them first (without if exists, but we wrap in a block)
  -- Or simpler, we just add them. Since this is an empty database, adding them directly is safe.
  alter publication supabase_realtime add table public.battle_sessions;
  alter publication supabase_realtime add table public.user_presences;
commit;

-- ────────────────────────────────────────────────────────────────────────────
-- 9. SEED 100 PROGRESSIVE ENGLISH VERBS (SYLLABUS SEED)
-- ────────────────────────────────────────────────────────────────────────────
insert into public.verbs (infinitive, spanish, past_simple, past_participle, gerund, example_en, example_es, difficulty) values
-- BASIC VERBS (Unidad 1 & 2)
('to be', 'ser / estar', 'was / were', 'been', 'being', 'I want to be a doctor.', 'Quiero ser médico.', 'basic'),
('to have', 'tener', 'had', 'had', 'having', 'We have a nice house.', 'Tenemos una casa bonita.', 'basic'),
('to do', 'hacer (acciones/tareas)', 'did', 'done', 'doing', 'I always do my homework.', 'Siempre hago mis tareas.', 'basic'),
('to go', 'ir', 'went', 'gone', 'going', 'They went to Paris last year.', 'Ellos fueron a París el año pasado.', 'basic'),
('to say', 'decir', 'said', 'said', 'saying', 'What did you say?', '¿Qué dijiste?', 'basic'),
('to get', 'obtener / conseguir / llegar', 'got', 'got / gotten', 'getting', 'Can you get some milk?', '¿Puedes conseguir algo de leche?', 'basic'),
('to make', 'hacer / fabricar / crear', 'made', 'made', 'making', 'She made a delicious cake.', 'Ella hizo un pastel delicioso.', 'basic'),
('to know', 'saber / conocer', 'knew', 'known', 'knowing', 'I know the answer.', 'Sé la respuesta.', 'basic'),
('to think', 'pensar', 'thought', 'thought', 'thinking', 'I think you are right.', 'Pienso que tienes razón.', 'basic'),
('to take', 'tomar / llevar', 'took', 'taken', 'taking', 'Please take this umbrella.', 'Por favor, llévate este paraguas.', 'basic'),
('to see', 'ver', 'saw', 'seen', 'seeing', 'I saw a shooting star.', 'Vi una estrella fugaz.', 'basic'),
('to come', 'venir', 'came', 'come', 'coming', 'Come to my party tonight!', '¡Ven a mi fiesta esta noche!', 'basic'),
('to want', 'querer', 'wanted', 'wanted', 'wanting', 'They want some ice cream.', 'Ellos quieren helado.', 'basic'),
('to use', 'usar / utilizar', 'used', 'used', 'using', 'Can I use your phone?', '¿Puedo usar tu teléfono?', 'basic'),
('to find', 'encontrar', 'found', 'found', 'finding', 'I cannot find my keys.', 'No puedo encontrar mis llaves.', 'basic'),
('to give', 'dar', 'gave', 'given', 'giving', 'Give me your hand.', 'Dame tu mano.', 'basic'),
('to tell', 'decir / contar / narrar', 'told', 'told', 'telling', 'He told us a funny story.', 'Él nos contó una historia graciosa.', 'basic'),
('to work', 'trabajar / funcionar', 'worked', 'worked', 'working', 'She works in an office.', 'Ella trabaja en una oficina.', 'basic'),
('to try', 'intentar / probar', 'tried', 'tried', 'trying', 'Let’s try this food.', 'Probemos esta comida.', 'basic'),
('to ask', 'preguntar / pedir', 'asked', 'asked', 'asking', 'Ask him for directions.', 'Pregúntale cómo llegar.', 'basic'),
('to feel', 'sentir', 'felt', 'felt', 'feeling', 'I feel very happy today.', 'Me siento muy feliz hoy.', 'basic'),
('to become', 'llegar a ser / convertirse en', 'became', 'become', 'becoming', 'She became a successful lawyer.', 'Ella se convirtió en una abogada exitosa.', 'basic'),
('to leave', 'dejar / salir / abandonar', 'left', 'left', 'leaving', 'The train leaves at 9 AM.', 'El tren sale a las 9 AM.', 'basic'),
('to put', 'poner / colocar', 'put', 'put', 'putting', 'Put the keys on the table.', 'Pon las llaves sobre la mesa.', 'basic'),
('to mean', 'significar / querer decir', 'meant', 'meant', 'meaning', 'What does this word mean?', '¿Qué significa esta palabra?', 'basic'),
('to keep', 'mantener / guardar', 'kept', 'kept', 'keeping', 'Keep your room clean.', 'Mantén tu habitación limpia.', 'basic'),
('to let', 'permitir / dejar', 'let', 'let', 'letting', 'Let me explain the rule.', 'Déjame explicar la regla.', 'basic'),
('to begin', 'comenzar / empezar', 'began', 'begun', 'beginning', 'The show will begin soon.', 'El espectáculo comenzará pronto.', 'basic'),
('to seem', 'parecer', 'seemed', 'seemed', 'seeming', 'You seem tired today.', 'Pareces cansado hoy.', 'basic'),
('to help', 'ayudar', 'helped', 'helped', 'helping', 'Can you help me?', '¿Puedes ayudarme?', 'basic'),
('to talk', 'hablar / conversar', 'talked', 'talked', 'talking', 'We talked for hours.', 'Hablamos durante horas.', 'basic'),
('to turn', 'girar / voltear / convertirse', 'turned', 'turned', 'turning', 'Turn left at the corner.', 'Gira a la izquierda en la esquina.', 'basic'),
('to start', 'empezar / comenzar / encender', 'started', 'started', 'starting', 'When does the class start?', '¿Cuándo empieza la clase?', 'basic'),
('to show', 'mostrar / enseñar', 'showed', 'shown', 'showing', 'Show me your drawings.', 'Muéstrame tus dibujos.', 'basic'),
('to hear', 'oír / escuchar', 'heard', 'heard', 'hearing', 'Did you hear that sound?', '¿Oíste ese sonido?', 'basic'),
('to play', 'jugar / tocar (instrumento)', 'played', 'played', 'playing', 'They play football every Sunday.', 'Ellos juegan fútbol todos los domingos.', 'basic'),
('to run', 'correr', 'ran', 'run', 'running', 'She can run very fast.', 'Ella puede correr muy rápido.', 'basic'),
('to move', 'mover / mudarse', 'moved', 'moved', 'moving', 'We are moving to London next month.', 'Nos mudamos a Londres el próximo mes.', 'basic'),
('to live', 'vivir', 'lived', 'lived', 'living', 'I live in a small town.', 'Vivo en un pueblo pequeño.', 'basic'),
('to believe', 'creer', 'believed', 'believed', 'believing', 'I believe in you.', 'Creo en ti.', 'basic'),

-- INTERMEDIATE VERBS (Unidad 3)
('to bring', 'traer', 'brought', 'brought', 'bringing', 'Bring your coat, it is cold.', 'Trae tu abrigo, hace frío.', 'intermediate'),
('to understand', 'entender / comprender', 'understood', 'understood', 'understanding', 'Do you understand this?', '¿Entiendes esto?', 'intermediate'),
('to meet', 'conocer / reunirse con', 'met', 'met', 'meeting', 'Nice to meet you.', 'Gusto en conocerte.', 'intermediate'),
('to learn', 'aprender', 'learned / learnt', 'learned / learnt', 'learning', 'We are learning English.', 'Estamos aprendiendo inglés.', 'intermediate'),
('to build', 'construir', 'built', 'built', 'building', 'They built a new bridge.', 'Ellos construyeron un nuevo puente.', 'intermediate'),
('to spend', 'gastar (dinero) / pasar (tiempo)', 'spent', 'spent', 'spending', 'I spent all my money.', 'Gasté todo mi dinero.', 'intermediate'),
('to buy', 'comprar', 'bought', 'bought', 'buying', 'She bought a new laptop.', 'Ella compró una nueva laptop.', 'intermediate'),
('to choose', 'elegir / escoger', 'chose', 'chosen', 'choosing', 'Choose your favorite color.', 'Elige tu color favorito.', 'intermediate'),
('to draw', 'dibujar', 'drew', 'drawn', 'drawing', 'Draw a circle on the paper.', 'Dibuja un círculo en el papel.', 'intermediate'),
('to fall', 'caer', 'fell', 'fallen', 'falling', 'Leaves fall in autumn.', 'Las hojas caen en otoño.', 'intermediate'),
('to grow', 'crecer', 'grew', 'grown', 'growing', 'Plants grow fast with water.', 'Las plantas crecen rápido con agua.', 'intermediate'),
('to send', 'enviar', 'sent', 'sent', 'sending', 'Send me an email.', 'Envíame un correo.', 'intermediate'),
('to speak', 'hablar (un idioma o formal)', 'spoke', 'spoken', 'speaking', 'He speaks three languages.', 'Él habla tres idiomas.', 'intermediate'),
('to write', 'escribir', 'wrote', 'written', 'writing', 'Write a letter to your friend.', 'Escribe una carta a tu amigo.', 'intermediate'),
('to lose', 'perder', 'lost', 'lost', 'losing', 'Don’t lose your key.', 'No pierdas tu llave.', 'intermediate'),
('to pay', 'pagar', 'paid', 'paid', 'paying', 'I need to pay the bills.', 'Necesito pagar las facturas.', 'intermediate'),
('to meet expectations', 'cumplir expectativas', 'met expectations', 'met expectations', 'meeting expectations', 'The results met our expectations.', 'Los resultados cumplieron nuestras expectativas.', 'intermediate'),
('to lead', 'guiar / liderar', 'led', 'led', 'leading', 'She leads a team of ten.', 'Ella lidera un equipo de diez.', 'intermediate'),
('to read', 'leer', 'read', 'read', 'reading', 'I read an interesting book.', 'Leí un libro interesante.', 'intermediate'),
('to understand fully', 'comprender totalmente', 'understood fully', 'understood fully', 'understanding fully', 'Now I understand fully.', 'Ahora comprendo totalmente.', 'intermediate'),
('to break', 'romper', 'broke', 'broken', 'breaking', 'Be careful not to break the vase.', 'Ten cuidado de no romper el florero.', 'intermediate'),
('to cut', 'cortar', 'cut', 'cut', 'cutting', 'Cut the cake into pieces.', 'Corta el pastel en pedazos.', 'intermediate'),
('to sell', 'vender', 'sold', 'sold', 'selling', 'They sell organic vegetables.', 'Ellos venden vegetales orgánicos.', 'intermediate'),
('to buy wholesale', 'comprar al por mayor', 'bought wholesale', 'bought wholesale', 'buying wholesale', 'We bought wholesale to save money.', 'Compramos al por mayor para ahorrar dinero.', 'intermediate'),
('to forget', 'olvidar', 'forgot', 'forgotten', 'forgetting', 'Don’t forget to call me.', 'No te olvides de llamarme.', 'intermediate'),
('to teach', 'enseñar', 'taught', 'taught', 'teaching', 'He teaches mathematics.', 'Él enseña matemáticas.', 'intermediate'),
('to offer', 'ofrecer', 'offered', 'offered', 'offering', 'They offered me a job.', 'Me ofrecieron un trabajo.', 'intermediate'),
('to consider', 'considerar', 'considered', 'considered', 'considering', 'Please consider my advice.', 'Por favor considera mi consejo.', 'intermediate'),
('to suggest', 'sugerir', 'suggested', 'suggested', 'suggesting', 'I suggest staying home.', 'Sugiero quedarse en casa.', 'intermediate'),
('to expect', 'esperar / prever', 'expected', 'expected', 'expecting', 'We expect rain tomorrow.', 'Esperamos lluvia mañana.', 'intermediate'),

-- ADVANCED VERBS (Unidad 4)
('to achieve', 'lograr / alcanzar', 'achieved', 'achieved', 'achieving', 'He achieved his goals.', 'Él logró sus metas.', 'advanced'),
('to foster', 'fomentar / promover', 'fostered', 'fostered', 'fostering', 'We must foster creativity.', 'Debemos fomentar la creatividad.', 'advanced'),
('to leverage', 'aprovechar / potenciar', 'leveraged', 'leveraged', 'leveraging', 'Leverage your digital skills.', 'Aprovecha tus habilidades digitales.', 'advanced'),
('to tackle', 'afrontar / abordar', 'tackled', 'tackled', 'tackling', 'Let’s tackle this problem.', 'Abordemos este problema.', 'advanced'),
('to enhance', 'mejorar / optimizar', 'enhanced', 'enhanced', 'enhancing', 'We want to enhance user experience.', 'Queremos mejorar la experiencia del usuario.', 'advanced'),
('to dynamicize', 'dinamizar', 'dynamicized', 'dynamicized', 'dynamicizing', 'Dynamicize the classroom environment.', 'Dinamizar el ambiente del aula.', 'advanced'),
('to facilitate', 'facilitar', 'facilitated', 'facilitated', 'facilitating', 'The guide will facilitate learning.', 'La guía facilitará el aprendizaje.', 'advanced'),
('to implement', 'implementar / poner en marcha', 'implemented', 'implemented', 'implementing', 'We implemented the new strategy.', 'Implementamos la nueva estrategia.', 'advanced'),
('to prioritize', 'priorizar', 'prioritized', 'prioritized', 'prioritizing', 'You should prioritize your health.', 'Deberías priorizar tu salud.', 'advanced'),
('to coordinate', 'coordinar', 'coordinated', 'coordinated', 'coordinating', 'Who is coordinating the event?', '¿Quién está coordinando el evento?', 'advanced'),
('to streamline', 'optimizar / simplificar', 'streamlined', 'streamlined', 'streamlining', 'Streamline the registration process.', 'Simplifica el proceso de registro.', 'advanced'),
('to master', 'dominar', 'mastered', 'mastered', 'mastering', 'She mastered the piano in years.', 'Ella dominó el piano en unos años.', 'advanced'),
('to establish', 'establecer', 'established', 'established', 'establishing', 'They established a new branch.', 'Ellos establecieron una nueva sucursal.', 'advanced'),
('to challenge', 'desafiar / retar', 'challenged', 'challenged', 'challenging', 'The task challenged his skills.', 'La tarea desafió sus habilidades.', 'advanced'),
('to accelerate', 'acelerar', 'accelerated', 'accelerated', 'accelerating', 'Accelerate the loading speed.', 'Acelera la velocidad de carga.', 'advanced'),
('to analyze', 'analizar', 'analyzed', 'analyzed', 'analyzing', 'We analyzed the market reports.', 'Analizamos los reportes de mercado.', 'advanced'),
('to maximize', 'maximizar', 'maximized', 'maximized', 'maximizing', 'Maximize your learning potential.', 'Maximiza tu potencial de aprendizaje.', 'advanced'),
('to negotiate', 'negociar', 'negotiated', 'negotiated', 'negotiating', 'He negotiated a better contract.', 'Él negoció un mejor contrato.', 'advanced'),
('to overcome', 'superar / vencer', 'overcame', 'overcome', 'overcoming', 'She overcame her fear of speaking.', 'Ella superó su miedo a hablar.', 'advanced'),
('to pursue', 'perseguir / buscar', 'pursued', 'pursued', 'pursuing', 'Pursue your academic dreams.', 'Busca tus sueños académicos.', 'advanced'),
('to resolve', 'resolver', 'resolved', 'resolved', 'resolving', 'They resolved the dispute quickly.', 'Resolvieron la disputa rápidamente.', 'advanced'),
('to strengthen', 'fortalecer', 'strengthened', 'strengthened', 'strengthening', 'This exercise strengthens muscles.', 'Este ejercicio fortalece los músculos.', 'advanced'),
('to transform', 'transformar', 'transformed', 'transformed', 'transforming', 'AI is transforming the industry.', 'La IA está transformando la industria.', 'advanced'),
('to undertake', 'emprender / asumir', 'undertook', 'undertaken', 'undertaking', 'We will undertake this adventure.', 'Emprenderemos esta aventura.', 'advanced'),
('to advocate', 'abogar por / defender', 'advocated', 'advocated', 'advocating', 'She advocates for animal rights.', 'Ella aboga por los derechos de los animales.', 'advanced'),
('to compile', 'compilar / recopilar', 'compiled', 'compiled', 'compiling', 'We compiled 100 verbs for learning.', 'Compilamos 100 verbos para el aprendizaje.', 'advanced'),
('to execute', 'ejecutar / llevar a cabo', 'executed', 'executed', 'executing', 'Execute the plan immediately.', 'Ejecuta el plan inmediatamente.', 'advanced'),
('to undergo', 'experimentar / someterse a', 'underwent', 'undergone', 'undergoing', 'The city is undergoing changes.', 'La ciudad está experimentando cambios.', 'advanced'),
('to mitigate', 'mitigar / atenuar', 'mitigated', 'mitigated', 'mitigating', 'Mitigate the risks of errors.', 'Mitiga los riesgos de errores.', 'advanced'),
('to excel', 'sobresalir / destacar', 'excelled', 'excelled', 'excelling', 'She excels in writing beautiful apps.', 'Ella sobresale en escribir hermosas apps.', 'advanced')
on conflict (infinitive) do nothing;

-- ────────────────────────────────────────────────────────────────────────────
-- FRIENDSHIPS SYSTEM
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.friendships (
    id uuid default gen_random_uuid() primary key,
    sender_id uuid references public.profiles(id) on delete cascade not null,
    receiver_id uuid references public.profiles(id) on delete cascade not null,
    status text not null check (status in ('pending', 'accepted', 'declined')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique (sender_id, receiver_id)
);

-- Enable RLS
alter table public.friendships enable row level security;

-- Policies for friendships
create policy "Users can view their own friendships"
on public.friendships for select
using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Users can insert friendships"
on public.friendships for insert
with check (auth.uid() = sender_id);

create policy "Users can update their received/sent friendships"
on public.friendships for update
using (auth.uid() = receiver_id or auth.uid() = sender_id);

create policy "Users can delete their own friendships"
on public.friendships for delete
using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Enable Realtime
alter publication supabase_realtime add table public.friendships;
