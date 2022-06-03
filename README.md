## Jeopardy!


### History
___

After Steve Brooks left in May 2022, I have taken over morning Jeopardy to honor him, because it's fun, and because I'm bad at answering the questions. Steve used a google sheet to keep track of all the stats and calculate monthly rankings, but after changing over then month once I thought it would be way more fun to write a program to do it for me.

The movitvation to choose Perl was pretty simple. I wanted a standalone scripting language that wasn't python or something I had used before. Perl fit the bill and it has a huge support community, plus I was intrigued by some of the syntactical weirdness as well as its similarity to C++ which was my first favorite language.


### Design
___

I've always liked the challenge and restrictions that come with a command line application, plus it was by far the easiest option. The program at its most basic will take one or more names, a date, and an amount which will then be added as score entries into the dataset.

The complexity comes from trying to make this program as robust as possible, and solving familiar problems in a new language. A reliable program is very important in this case because the dataset is nothing more than a csv, so things can be easily mangled.

Another aspect that I wanted to explore was making the program as intuitive as possible. This included things like case insensitivity, writing 'today' for the date, and being able to select more than one person at a time. Writing a program that I would want to use, with features that you would expect from a modern application was a priority.


### Usage
---

Because of my trek towards usability, the program is fairly self explanatory but I will provide some under the hood knowledge to better understand how it works.

Coming soon...