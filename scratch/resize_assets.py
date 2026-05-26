import os
import sys

print("Checking dependencies...")
try:
    from PIL import Image
    print("Pillow is installed!")
except ImportError:
    print("Pillow is not installed. Installing it now...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
    from PIL import Image

def resize_icon(src_path, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, "app_icon_512.png")
    
    with Image.open(src_path) as img:
        # Resize to 512x512 using high-quality resampling
        resized_img = img.resize((512, 512), Image.Resampling.LANCZOS)
        resized_img.save(dest_path, "PNG", optimize=True)
        print(f"Icon resized and saved to {dest_path} (size: {os.path.getsize(dest_path)} bytes)")

if __name__ == "__main__":
    src_icon = "/Users/danny/Desktop/proyectos/ingles/miriverbs/assets/images/logo.png"
    dest_folder = "/Users/danny/Desktop/Google Play/Mirivers"
    resize_icon(src_icon, dest_folder)
