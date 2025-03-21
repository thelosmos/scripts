import sys
import os
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from PIL import Image, ImageDraw, ImageFont

def capture_screenshot(url, output_path):
    # Set up Selenium WebDriver for Chromium
    chrome_options = Options()
    chrome_options.binary_location = "/usr/bin/chromium"  # Update with the path to your Chromium browser
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--window-size=1920x1080")
    chrome_options.add_argument("--disable-gpu")
    
    driver_path = "/usr/bin/chromedriver"  # Update with the path to your ChromeDriver
    driver = webdriver.Chrome(service=Service(driver_path), options=chrome_options)
    
    try:
        # Open the webpage
        driver.get(url)

        # Capture full-page screenshot
        screenshot_path = output_path
        driver.save_screenshot(screenshot_path)

        # Add footer with URL and timestamp
        annotate_screenshot(screenshot_path, url)
        print(f"Screenshot saved for {url} at {screenshot_path}")
    except Exception as e:
        print(f"Error capturing screenshot for {url}: {e}")
    finally:
        driver.quit()

def annotate_screenshot(image_path, url):
    # Open the screenshot
    image = Image.open(image_path)
    
    # Set up footer text
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    footer_text = f"URL: {url} | Captured on: {timestamp}"
    
    # Add footer to the image
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()  # You can specify a TTF font file if desired
    text_width, text_height = draw.textsize(footer_text, font=font)
    footer_height = text_height + 10
    new_height = image.height + footer_height
    
    # Create a new image with space for the footer
    annotated_image = Image.new("RGB", (image.width, new_height), (255, 255, 255))
    annotated_image.paste(image, (0, 0))
    draw = ImageDraw.Draw(annotated_image)
    draw.text((10, image.height + 5), footer_text, fill="black", font=font)
    
    # Save the annotated image
    annotated_image.save(image_path)

def main():
    # Ensure URLs are piped via standard input
    urls = [line.strip() for line in sys.stdin if line.strip()]
    output_dir = "screenshots"
    os.makedirs(output_dir, exist_ok=True)
    
    for idx, url in enumerate(urls):
        output_path = os.path.join(output_dir, f"screenshot_{idx + 1}.png")
        capture_screenshot(url, output_path)

if __name__ == "__main__":
    main()
