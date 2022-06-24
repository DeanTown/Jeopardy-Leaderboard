#!/bin/bash

# Install needed modules for the trivia script
cpanm Text::CSV
cpanm Data::Dumper
cpanm Scalar::Util
cpanm Time::Piece
cpanm Term::ANSIScreen
cpanm Term::ReadKey

# Run the script once the install is finished
perl trivia.pl