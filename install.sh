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
    'zero': ["let's go for a walk", "I'm bored, you wanna talk?", "put on warm fuzzy socks", "dump GameStop stock", "party on our block", "the Captain is Spock"],
    'one': ["the day has just begun", "let's have some fun", "enjoy the sun", "abolish war and guns", "fight the system, it's just begun", "read a book for fun", "you should know that you stun"],
    'two': ["paint your nails blue", "kick off your shoes", "there's so much to do", "free the animals in the zoo", "two books, one for me, one for you", "overthrowing the government is a coup"],
    'three': ["the pollinating bee", "climb the oak trees", "I once had a Peruvian monkey", "may you always be free", "busy as a bee", "more than what you see", "free thought, let it be"],
    'four': ["open the magic door", "roll on the floor", "avoid the stores", "let's explore the shore", "end all war", "ideas, let them pour", "writing code we adore"],
    'five': ["let's go for a drive", "pretty UI", "brah, high five", "may you feel so alive", "let's strive to thrive", "always question why", "with books, imaginations thrive"],
    'six': ["pick up sticks", "a mason lays bricks", "Allie loves to give licks", "all things can be fixed", "learn magic tricks", "let's see Stevie Nicks"],
    'seven': ["nothing rhymes with seven", "stairway to heaven", "some bread has no leaven"],
    'eight': ["it's never too late", "Skyler, you're so great", "a metamorphic rock is slate", "there's no room for hate", "books stimulate", "let's go on a date"],
    'nine': ["you're fine and divine", "you make the stars align", "everything's going fine", "I see you shine", "I love that you're mine", "your code and mine", "challenge the line", "on cloud nine with a good storyline"],
    'ten': ["a fireplace in the den", "an egg-laying chicken is a hen", "make art with ink and pen", "pushing changes again"],
    'eleven': ["almost seven", "like a slice of heaven", "I'll be home by seven", "my godson is Devon"],
    'twelve': ["galaxy on the shelf", "happy plants on the shelf", "I like pooping by myself", "pretty plants on the shelf", "be proud of yourself", "stories the library delves", "pick a book from the shelf"],
    'teen': ["it's not a bad idea to clean", "put down the screen", "always follow your dreams", "revolution is clean", "Jack had a magic bean"],
    'ty': ["let's feed the birdies", "Skyler, you're so pretty", "let's visit the city", "Skyler, you're so witty"]
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
        minute_word = "o' clock"
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
def get_rhymes():
    with open('/home/pi/rhymes.txt', 'r') as rhymes_file:
        return rhymes_file.readlines()

rhymes = get_rhymes()

# Setup the e-ink display
epd = epd7in5_V2.EPD()
epd.init()
epd.Clear()

# Prepare for drawing
image = Image.new('1', (epd.width, epd.height), 255)
draw = ImageDraw.Draw(image)
font64 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 64)
font32 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 32)

def display_splash_screens(epd, image_path1,  display_time):
    for image_path in [image_path1]:
        print(f'Displaying splash screen: {image_path}')
        image = Image.open(image_path).convert("L")
        aspect_ratio = image.width / image.height
        new_width = epd.width
        new_height = int(new_width / aspect_ratio)
        image = image.resize((new_width, new_height), Image.LANCZOS)
        image_bw = Image.new("1", (epd.width, epd.height), 255)
        image_bw.paste(image, ((epd.width - new_width) // 2, (epd.height - new_height) // 2))

        epd.display(epd.getbuffer(image_bw))
        time.sleep(display_time)
        epd.init()

# Display splash screens
splash_image_path1 = "/home/pi/splash-sky-clock.png"
display_splash_screens(epd, splash_image_path1, 2)

# Main execution
def generate_rhymes():
    with open('/home/pi/rhymes.txt', 'w') as rhymes_file:
        for hour in range(24):
            for minute in range(60):
                rhyme = create_rhyme(hour, minute)
                print(f'Generating rhyme for {hour}:{minute} -> {rhyme}')  # log the rhyme
                rhymes_file.write(rhyme + "\n")

while True:
    # Fetch the current time
    now = datetime.now()
    current_time = now.strftime("%l:%M %p").lstrip()  # lstrip to remove any leading space

    # Check if it's midnight, if yes, then regenerate rhymes
    if now.hour == 0 and now.minute == 0:
        generate_rhymes()
        rhymes = get_rhymes()

    rhyme_index = now.hour * 60 + now.minute
    current_rhyme = rhymes[rhyme_index].strip()

    # Clear the image
    draw.rectangle([(0,0),(epd.width, epd.height)], fill = 255)  

    # Draw the time and the rhyme
    draw.text((40, 48), current_time, font = font32, fill = 0)  

    # Wrap the rhyme text
    wrap_rhyme = textwrap.wrap(current_rhyme, width=20)

    for i, line in enumerate(wrap_rhyme):
        y_text = 128 + i*76
        draw.text((40, y_text), line, font=font64, fill=0)

    # Rotate the image
    rotated_image = image.rotate(-90, expand=True)

    # Update the display
    epd.display(epd.getbuffer(rotated_image))

    # Wait for 60 seconds
    time.sleep(60)
EOL

# Download splash screen images
wget -P /home/pi/ https://raw.githubusercontent.com/scidsg/brand-resources/main/logos/splash-lg.png
wget -P /home/pi/ https://raw.githubusercontent.com/glenn-sorrentino/sky-clock/main/logos/splash-sky-clock.png

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
StandardOutput=journal
StandardError=journal
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
