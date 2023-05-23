import random

def create_rhyme(hour, minute):
    # A list of words for rhyming with minute's last digit
    rhyme_words = {
        "0": ["hero", "zero", "sparrow", "burrow"],
        "1": ["fun", "sun", "run", "bun"],
        "2": ["zoo", "blue", "shoe", "two"],
        "3": ["tree", "free", "sea", "bee"],
        "4": ["door", "floor", "core", "oar"],
        "5": ["hive", "drive", "alive", "dive"],
        "6": ["mix", "sticks", "bricks", "kicks"],
        "7": ["heaven", "eleven", "seven", "leaven"],
        "8": ["gate", "fate", "plate", "eight"],
        "9": ["line", "nine", "fine", "wine"]
    }
    minute_last_digit = str(minute)[-1]
    rhyme_word = random.choice(rhyme_words[minute_last_digit])
    time_str = f"{hour}:{str(minute).zfill(2)}"
    return f"At {time_str}, let's feel like a {rhyme_word}!"

with open('rhymes.txt', 'w') as rhymes_file:
    for hour in range(24):
        for minute in range(60):
            rhymes_file.write(create_rhyme(hour, minute) + "\n")
