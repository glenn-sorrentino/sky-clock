#!/bin/bash

# Update
sudo apt update
sudo apt-get -y dist-upgrade
sudo apt-get install -y python3-pip whiptail

# Welcome Prompt
whiptail --title "E-Ink Display Setup" --msgbox "The e-paper hat communicates with the Raspberry Pi using the SPI interface, so you need to enable it.\n\nNavigate to \"Interface Options\" > \"SPI\" and select \"Yes\" to enable the SPI interface." 12 64
sudo raspi-config

# Install Waveshare e-Paper library
git clone https://github.com/waveshare/e-Paper.git
pip3 install ./e-Paper/RaspberryPi_JetsonNano/python/
pip3 install qrcode[pil]

# Install other Python packages
pip3 install RPi.GPIO spidev datetime

# Enable SPI interface
if ! grep -q "dtparam=spi=on" /boot/config.txt; then
    echo "dtparam=spi=on" | sudo tee -a /boot/config.txt
    echo "SPI interface enabled."
else
    echo "SPI interface is already enabled."
fi

cat > /home/pi/generate_rhymes.py << EOL
#!/usr/bin/env python3

import random

def num_to_words(num, join_tens=False):
    under_20 = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen']
    tens = ['Twenty', 'Thirty', 'Forty', 'Fifty']
    if num < 20:
        return 'o-' + under_20[num] if join_tens else under_20[num]
    elif num < 60:
        return tens[(num // 10) - 2] + ('' if num % 10 == 0 else ' ' + under_20[num % 10])
    return ''

# Minute rhymes
minute_rhymes = {
    'zero': ["let's go for a walk", "I'm bored, you wanna talk?", "put on warm fuzzy socks", "dump GameStop stock", "party on our block!"],
    'one': ["the day has just begun", "let's have some fun", "enjoy the sun", "abolish war and guns", "fight the system, it's just begun", "read a book for fun"],
    'two': ["paint your nails blue", "we don't need any shoes", "there's so much to do", "free the animals in the zoo", "two books, one for me, one for you"],
    'three': ["the pollinating bee", "climb the oak trees", "I once had a Peruvian monkey", "may you always be free", "busy as a bee", "more than what you see", "free thought, let it be"],
    'four': ["open the magic door", "roll on the floor", "avoid the stores", "let's explore the shore", "end all war", "ideas, let them pour", "writing code we adore"],
    'five': ["let's go for a drive", "pretty UI", "brah, high five", "may you feel so alive", "let's strive to thrive", "always question why", "with books, imaginations thrive"],
    'six': ["pick up sticks", "a mason lays bricks", "Allie loves to give licks", "all things can be fixed", "learn magic tricks"],
    'seven': ["nothing rhymes with seven", "stairway to heaven", "some bread has no leaven"],
    'eight': ["it's never too late", "Skyler, you're so great", "there's no room for hate", "books stimulate"],
    'nine': ["you're fine and divine", "you make the stars align", "everything's going fine", "I see you shine", "I love that you're mine", "your code and mine"],
    'ten': ["a fireplace in the den", "an egg-laying chicken is a hen", "make art with ink and pen", "pushing changes again"],
    'eleven': ["almost seven", "like a slice of heaven", "I'll be home by seven"],
    'twelve': ["galaxy on the shelf", "happy plants on the shelf", "I like pooping by myself", "pretty plants on the shelf", "be proud of yourself", "stories the library delves", "pick a book from the shelf"],
    'teen': ["it's not a bad idea to clean", "put down the screen", "always follow your dreams", "revolution is clean", "challenge the line", "on cloud nine with a good storyline"],
    'ty': ["let's feed the birdies", "Skyler you're so pretty", "let's visit the city", "Skyler, you're so witty"]
}

def create_rhyme(hour, minute):
    # Special case for midnight and noon
    if hour == 0 and minute == 0:
        return "It's midnight, all is quiet and right."
    elif hour == 12 and minute == 0:
        return "It's noon, time to listen to a tune."

    # Convert 24-hour format to 12-hour format
    if hour == 0 or hour == 12:
        hour_12 = 12
    else:
        hour_12 = hour if hour < 12 else hour - 12

    # Special cases for minute words
    if minute == 0:
        minute_word = 'o clock'
        minute_rhyme = random.choice(minute_rhymes['zero'])
    elif 1 <= minute <= 9:
        minute_word = f"o' {num_to_words(minute).lower()}"
        minute_rhyme = random.choice(minute_rhymes[minute_word.split()[1]])
    elif 10 <= minute <= 12:
        minute_word = num_to_words(minute).lower()
        minute_rhyme = random.choice(minute_rhymes[minute_word])
    elif 13 <= minute <= 19:
        minute_word = num_to_words(minute).lower()
        minute_rhyme = random.choice(minute_rhymes['teen'])
    elif 20 <= minute < 60 and minute % 10 == 0:
        minute_word = num_to_words(minute).lower()
        minute_rhyme = random.choice(minute_rhymes['ty'])
    elif 20 <= minute < 60:
        minute_word = num_to_words(minute).lower()
        minute_tens = minute_word.split()[0] + ' ' + minute_word.split()[1] # e.g., 'twenty two'
        minute_rhyme = random.choice(minute_rhymes[minute_word.split()[1]])
    else:
        minute_word = num_to_words(minute, join_tens=True).lower().split()[-1]
        minute_rhyme = random.choice(minute_rhymes[minute_word])

    rhyme = f"It's {num_to_words(hour_12).lower()} {minute_word}, {minute_rhyme}."
    return rhyme

# Main execution
with open('/home/pi/rhymes.txt', 'w') as rhymes_file:
    for hour in range(24):
        for minute in range(60):
            rhymes_file.write(create_rhyme(hour, minute) + "\n")
EOL

# Generate the rhymes and save in a text file
python3 /home/pi/generate_rhymes.py

# Create a new script to display status on the e-ink display
cat > /home/pi/kid_clock.py << EOL
#!/usr/bin/env python3

import os
import sys
import time
import textwrap
from datetime import datetime
from waveshare_epd import epd7in5_V2
from PIL import Image, ImageDraw, ImageFont

# Fetch rhymes from the file
with open('/home/pi/rhymes.txt', 'r') as rhymes_file:
    rhymes = rhymes_file.readlines()

# Setup the e-ink display
epd = epd7in5_V2.EPD()
epd.init()
epd.Clear()

# Prepare for drawing
image = Image.new('1', (epd.width, epd.height), 255)  # width and height in correct order
draw = ImageDraw.Draw(image)
font36 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 36)
font16 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 16)

def display_splash_screens(epd, image_path1, image_path2, display_time, new_height):
    for image_path in [image_path1, image_path2]:
        print(f'Displaying splash screen: {image_path}')
        image = Image.open(image_path).convert("L")

        # Calculate new width while maintaining the aspect ratio
        aspect_ratio = image.width / image.height
        new_width = int(new_height * aspect_ratio)
        
        image = image.resize((new_width, new_height), Image.ANTIALIAS)
        image_bw = Image.new("1", (epd.height, epd.width), 255)
        image_bw.paste(image, (0, 0))

        rotated_image_bw = image_bw.rotate(-90, expand=True)
        epd.display(epd.getbuffer(rotated_image_bw))
        time.sleep(display_time)
        epd.init()

# Display splash screens
splash_image_path1 = "/home/pi/splash-sm.png"
splash_image_path2 = "/home/pi/splash-sm-product.png"
new_height = 250  # or any value you prefer
display_splash_screens(epd, splash_image_path1, splash_image_path2, 3, new_height)

while True:
    # Fetch the current time
    now = datetime.now()
    current_time = now.strftime("%l:%M %p").lstrip()  # lstrip to remove any leading space

    rhyme_index = now.hour * 60 + now.minute
    current_rhyme = rhymes[rhyme_index].strip()

    # Clear the image
    draw.rectangle([(0,0),(epd.width, epd.height)], fill = 255)  # width and height in correct order

    # Draw the time and the rhyme
    draw.text((10, 10), current_time, font = font16, fill = 0)  # No need for the anchor, text will start from top-left

    # Wrap the rhyme text
    wrap_rhyme = textwrap.wrap(current_rhyme, width=26)

    for i, line in enumerate(wrap_rhyme):
        y_text = 54 + i*36  # the y-position for each line of text (adjusted to 36 to match the font size)
        draw.text((10, y_text), line, font=font36, fill=0)  # start text from left, adjusted to each new line

    # Rotate the image
    rotated_image = image.rotate(-90, expand=True)  # rotate clockwise

    # Update the display
    epd.display(epd.getbuffer(rotated_image))

    # Wait for 60 seconds
    time.sleep(60)
EOL

# Download splash screen images
wget -P /home/pi/ https://raw.githubusercontent.com/scidsg/brand-resources/main/logos/splash-sm.png
wget -P /home/pi/ https://raw.githubusercontent.com/glenn-sorrentino/sky-clock/main/logos/splash-sm-product.png

# Create a new script to display status on the e-ink display
cat > /etc/systemd/system/kidclock.service << EOL
[Unit]
Description=Kid Clock Service
After=multi-user.target

[Service]
Type=idle
ExecStart=/usr/bin/python3 /home/pi/kid_clock.py
Restart=always
User=pi
Group=pi
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=kidclock

[Install]
WantedBy=multi-user.target
EOL

sudo chmod 644 /etc/systemd/system/kidclock.service
sudo systemctl daemon-reload
sudo systemctl enable kidclock.service
sudo systemctl start kidclock.service
sudo systemctl status kidclock.service

# Start the kid clock
python3 /home/pi/kid_clock.py &
