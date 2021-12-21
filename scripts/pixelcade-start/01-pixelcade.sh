#!/bin/bash

#curl  --silent  "http://localhost:8080/text?t=Welcome%20to%20Russ's%20Arcade&color=cyan&font=Tall%20Films%20Fine&yoffset=-2"
#curl  --silent  "http://localhost:8080/text?t=Welcome%20to%20Russ's%20Arcade&color=cyan&font=Star%20Jedi%20Hollow&yoffset=-2"
rm -f /home/pi/pixelcade/.marquee-select > /dev/null 2>/dev/null
curl  --silent  "http://localhost:8080/text?t=Welcome%20to%20Russ's%20Arcade&color=green&font=ARCADE_I&yoffset=-2"



