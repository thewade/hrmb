Highway Route Marker Bot
========================
This is a bot run for Wikimedia Commons to create sequences of images and then convert the text to paths.

See: https://commons.wikimedia.org/wiki/User:Highway_Route_Marker_Bot

###Environment
This script was written in Ubuntu Linux. It could probably be modified to work on other operating systems, but support will only be provided for Ubuntu.

####Dependency’s
For the program to work, you must install the following packages:
<pre>
sudo apt-get install perl, libmediawiki-api-perl, inkscape
</pre>

#####Scour
It is recommend to also have Scour Command Line Script on you computer, you can download it at http://www.codedread.com/scour/.

Scour requires Python to run:
<pre>
sudo apt-get install python
</pre>

In the Perl script, please modify $scour to the path you installed Scour at. If left blank, the program will skip using Scour.
<pre>
$scour = "./scour/scour.py";
</pre>

###Usage
To use the program:
<pre>
perl routemarker.pl Highway_marker_%num%.svg sequence.txt wikitext.txt
</pre>
* Argument 1: The SVG file
* Argument 2: The sequence file
* Argument 3: The text file

#####The SVG file
The SVG file you are editing must contain an text object with the ID 'routenum'. That text object must contain string %num%, as this is what will be replaced by the sequence.  The filename must also include %num% in order to generate distinct files.
#####The sequence file
The sequence file must be comma delimited.
e.g.
<pre>
88, 14, 17
</pre>
#####The text file
This is a file that contains the text that will go on the comment field. For new uploads this must include [Template:Information](https://commons.wikimedia.org/wiki/Template:Information) and the [license](https://commons.wikimedia.org/wiki/Commons:Licensing). This file can also contain %num% for sequence replacements.
