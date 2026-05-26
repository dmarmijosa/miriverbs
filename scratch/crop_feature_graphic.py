import os
from PIL import Image

def crop_and_save():
    src_image_path = "/Users/danny/.gemini/antigravity/brain/f43ce73f-1320-42ea-92a5-681aada16a23/miriverbs_feature_graphic_1779744888912.png"
    dest_dir = "/Users/danny/Desktop/Google Play/Mirivers"
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, "feature_graphic.png")
    
    with Image.open(src_image_path) as img:
        width, height = img.size
        print(f"Original size: {width}x{height}")
        
        # Target is 1024x500
        target_w = 1024
        target_h = 500
        
        # We need a 1024x500 crop. Since original is 1024x1024,
        # let's crop the center part.
        left = 0
        top = (height - target_h) // 2
        right = target_w
        bottom = top + target_h
        
        print(f"Cropping box: left={left}, top={top}, right={right}, bottom={bottom}")
        cropped_img = img.crop((left, top, right, bottom))
        
        # Ensure exact resizing just in case
        cropped_img = cropped_img.resize((1024, 500), Image.Resampling.LANCZOS)
        
        # Save as PNG
        cropped_img.save(dest_path, "PNG", optimize=True)
        print(f"Feature graphic cropped and saved to {dest_path} (size: {os.path.getsize(dest_path)} bytes)")

if __name__ == "__main__":
    crop_and_save()
