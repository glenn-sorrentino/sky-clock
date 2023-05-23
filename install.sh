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
    'zero': ["let's go for a walk", "I'm bored, let's talk", "put on warm fuzzy socks"],
    'one': ["the day has just begun", "let's have some fun", "enjoy the sun", "abolish guns"],
    'two': ["I lost my shoe", "paint your nails blue", "I don't need any shoes", "there's so much to do"],
    'three': ["the pollinating bee", "climb the oak trees", "the Peruvian monkey", "may you always be free"],
    'four': ["open the door", "roll on the floor", "avoid the stores"],
    'five': ["let's go for a drive", "brah, high five", "I feel so alive"],
    'six': ["pick up sticks", "a mason lays bricks", "Allie can't stop giving licks", "all things can be fixed"],
    'seven': ["nothing rhymes with seven", "stairway to heaven", "manna is bread without leaven"],
    'eight': ["it's never too late", "I'm feeling great"],
    'nine': ["everything's fine", "I see you shine", "I love that you're mine"],
    'ten': ["let's go to the den", "I see a wren", "I'm using my pen"],
    'eleven': ["almost seven", "like a slice of heaven", "I'll be home by seven"],
    'twelve': ["on the shelf", "by myself", "like an elf"],
    'teen': ["it's time to clean", "put down the screen"],
    'ty': ["there's a birdie", "feeling pretty", "visiting the city", "dancing ditty", "being witty"]
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
import os
import sys
import time
import textwrap
from datetime import datetime
from waveshare_epd import epd2in13_V3
from PIL import Image, ImageDraw, ImageFont

# Fetch rhymes from the file
with open('/home/pi/rhymes.txt', 'r') as rhymes_file:
    rhymes = rhymes_file.readlines()

# Setup the e-ink display
epd = epd2in13_V3.EPD()
epd.init()
epd.Clear()

# Prepare for drawing
image = Image.new('1', (epd.height, epd.width), 255)
draw = ImageDraw.Draw(image)
font16 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 16)
font11 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 11)

while True:
    # Fetch the current time
    now = datetime.now()
    current_time = now.strftime("%l:%M %p").lstrip()  # lstrip to remove any leading space

    rhyme_index = now.hour * 60 + now.minute
    current_rhyme = rhymes[rhyme_index].strip()

    # Clear the image
    draw.rectangle([(0,0),(epd.height, epd.width)], fill = 255)

    # Draw the time and the rhyme
    draw.text((epd.height//2, 10), current_time, font = font11, fill = 0, anchor='mm')

    # Wrap the rhyme text
    wrap_rhyme = textwrap.wrap(current_rhyme, width=28)

    for i, line in enumerate(wrap_rhyme):
        y_text = 52 + i*20  # the y-position for each line of text
        draw.text((epd.height//2, y_text), line, font=font16, fill=0, anchor='mm')

    # Update the display
    epd.display(epd.getbuffer(image))

    # Wait for 60 seconds
    time.sleep(60)
EOL

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
