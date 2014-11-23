#! usr/bin/perl
use warnings;
use strict;
use MediaWiki::API;
use Term::ReadKey;

# Configuration
# ===================

my $replaceme = '%num%'; # replacement string, default %num%
my $scourpath = './scour/scour.py'; # where Scour CLS is located
my $textID = 'routenum'; # object ID of the text to be converted
my $delay = 10; # delay between uploading images
my $autoupload = 0; # prompts for input between uploads (0=false, 1=true)
my $username = "Highway Route Marker Bot"; # uploaders Mediawiki username
my $apiurl = 'http://commons.wikimedia.org/w/api.php'; # Mediawiki API location
my $uploadurl = 'http://commons.wikimedia.org/w/index.php?title=Special:Upload&uploadformstyle=basic'; # Mediawiki upload location

# Variables
# ===================

# Arguments
my $svgfilename = $ARGV[0]; # the SVG filename
my $sequencefile = $ARGV[1]; # the sequence filename
my $textfilename = $ARGV[2]; # the text filename

# SVG datafiles
my $basesvg; # the SVG file
my $outfile; # the new SVG file

# Other
my $sequencetxt; # sequence values 
my @sequence; # array of sequence values 
my $wikitext; # the un-sequenced text
my $outfilename; # the sequenced filename
my %ref_table; # hashtable that contains filename and file comment
my $password; # uploaders Mediawiki password
my $starttime; # used to speed limit the bot
my $sleeptime; # used to speed limit the bot

# Load the files, do some checks
# ===================

# Open the SVG file
open ( FILE, $svgfilename ) || die ("you die now!");
  $basesvg= do{local $/; <FILE>;};
close (FILE);

# Check for the replacement string in filename
if ($svgfilename =~ m/$replaceme/) { 
 print "basesvg includes the string $replaceme\n";
}
else {
 die ("The basesvg file must include the string $replaceme for sequencing. Program failed");
}

my $svgfilename_esc = quotemeta($svgfilename);

# Check for text with the proper object ID in SVG
if (`inkscape $svgfilename_esc --query-id=$textID --query-x`) {
 print "Object $textID found.\n";
}
else {
 die ("ERROR: Text with object ID $textID not found, please check the SVG file $svgfilename. Program failed");
}

# Open the sequencing file
open ( FILE, $sequencefile ) || die ("you die now!");

while (<FILE>){
 $sequencetxt .= $_;
}
close FILE;

@sequence = split(',', $sequencetxt);

# Open the Wikitext file
open ( FILE, $textfilename ) || die ("you die now!");
	$wikitext= do{local $/; <FILE>;};
close (FILE);

# Loop through the sequence
# ===================

foreach (@sequence) {
    my($line) = $_;
    chomp($line);
    $line =~ s/^\s+|\s+$//g;

    # Create SVG
    # =========================

    (my $outfile = $basesvg) =~ s/$replaceme/$line/g;
    (my $outfilename = $svgfilename) =~ s/$replaceme/$line/;

    # Hacking in some code to ignore already created files, this behavoir really should be user defined
    unless (-e $outfilename) {  

	print "\nCreating $outfilename \n";

	open ( FILE, ">$outfilename" ) || die ("you die now!");
	print FILE $outfile;
	close (FILE);

	# Text to Path & Optimize
	# =========================
	
	# You cannot use Inkscape verbs in the shell mode or without the GUI, so for now Inkscape will open and close as it does it's work
	print "Converting text-to-path...";
        system("inkscape", "$outfilename", "--select=$textID", "--verb=ObjectToPath", "--verb=FileSave", "--verb=FileClose");

        # Clean SVG with Scour
	if ($scourpath) {
		print "creating optimized SVG with Scour...\n\n";
        	system("python", $scourpath, "-i", $outfilename, "-o", "temp_" . $outfilename);
		unlink ($outfilename);
		rename ("temp_$outfilename", $outfilename);
	}

	# Fixing SVG in Inkscape
	print "\nResave file with Inkscape...";
        system("inkscape", $outfilename ,"--export-plain-svg=" . $outfilename);

    }    

    # Generate Wiki text
    # =======================================
    print "Generating Wikitext...\n";
    (my $outtext = $wikitext) =~ s/$replaceme/$line/g;
    $ref_table{$outfilename} = $outtext;

}

print "\nPlease review all images before uploading, press Y to proceed...\n";

ReadMode "cbreak";
$_ = ReadKey();
ReadMode "normal";

if(lc $_ eq 'y') {

	# Get user info
	if (!$username) {
		print "\nPlease enter your username: ";
		$username = <STDIN>;
		chomp($username);
	}
	print "$username, please enter your password: ";
	$password = <STDIN>;
	chomp($password);

	# Upload to Mediawiki
	# ==================================

	# Config
	my $mw = MediaWiki::API->new( { api_url => $apiurl }  ); 

	$mw->{config}->{upload_url} = $uploadurl;

	$mw->login( { lgname => $username, lgpassword => $password } )
	  || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

	# Cycle through images
	foreach my $key (sort keys %ref_table) {
                $outfilename = $key;
                $wikitext = $ref_table{$key};

		open ( FILE, $outfilename ) || die ("you die now!");
			my $outfile= do{local $/; <FILE>;};
		close (FILE);

		# Upload

		print ("Uploading...\n");
		$starttime = time;

		$mw->upload( { title => $outfilename,
		         summary => $wikitext,
		         data => $outfile } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

		print ("Uploaded: http://commons.wikimedia.org/wiki/File%3A$outfilename\n");

		if (!$autoupload) {
			print ("Please verify that images has uploaded.\n Press 'y' if the upload was good.\n Press 'a' to abort.\n Press 's' to skip this check\n");
		
			ReadMode "cbreak";
			$_ = ReadKey();
			ReadMode "normal";
			
			if(lc $_ eq 'a') { die ("you die now!"); }
			if(lc $_ eq 's') { $autoupload = 1; }
		}

		# Bot is speed limited due to http://commons.wikimedia.org/wiki/Commons:Bot#Bot_speed
		if ($starttime + $delay > time) {
			$sleeptime = $delay - (time - $starttime);
			print "Need to wait $sleeptime second(s)\n";
			sleep($sleeptime);
		}	
	}
}

