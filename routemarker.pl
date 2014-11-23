use warnings;
use strict;
use MediaWiki::API;
use Term::ReadKey;

# Configuration
# ===================

my $replaceme = '%num%'; # replacement string, default %num%
my $scourpath = './scour'; # where Scour CLS is located
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
my @sequence; # array of sequence values 
my $wikitext; # the un-sequenced text
my $outfilename; # the sequenced filename
my %ref_table; # hashtable that contains filename and file comment
my $password; # uploaders Mediawiki password

# Open the SVG file
open ( FILE, $svgfilename ) || die ("you die now!");
  $basesvg= do{local $/; <FILE>;};
close (FILE);

# Do some checks
if ($svgfilename =~ m/$replaceme/) { 
 print "Success\n";
}
else {
 print "The basesvg file must include the string $replaceme for sequencing\n\n";
}

# Open the sequencing file
open ( FILE, $sequencefile ) || die ("you die now!");
while(<FILE>) {
    my($line) = $_;
    push(@sequence, $_);
}
close (FILE);

# Open the Wikitext file
open ( FILE, $textfilename ) || die ("you die now!");
    $wikitext= do{local $/; <FILE>;};
close (FILE);

foreach (@sequence) {
    my($line) = $_;
    chomp($line);
    $line =~ s/^\s+|\s+$//g;

    # Create SVG
    # =========================

    (my $outfile = $basesvg) =~ s/$replaceme/$line/g;
    (my $outfilename = $svgfilename) =~ s/$replaceme/$line/;

    print "\nCreating $outfilename \n";

    open ( FILE, ">$outfilename" ) || die ("you die now!");
    print FILE $outfile;
    close (FILE);

    # Text to Path & Optimize
    # =========================
    
    # Text to path with Inkscape (need to convert to PDF because of bug)
    # See: https://bugs.launchpad.net/inkscape/+bug/517391
    print "Converting text-to-path...";
    system("inkscape", "$outfilename", "--export-pdf=$outfilename.pdf", "--export-text-to-path");
    unlink ($outfilename);

    # PDF back to SVG
    print "convert back to SVG...";
    system("pdf2svg", "$outfilename.pdf", "$outfilename");
    unlink ("$outfilename.pdf");

    # Clean SVG with Scour
    if ($scourpath) {
        print "creating optimized SVG with Scour...\n\n";
        system("python $scourpath/scour.py -i $outfilename -o temp_$outfilename");
        unlink ($outfilename);
        rename ("temp_$outfilename", $outfilename);
    }

    # Fixing SVG in Inkscape
    print "\nResave file with Inkscape...";
    system("inkscape", $outfilename ,"--export-plain-svg=$outfilename");

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
    while (($outfilename, $wikitext) = each(%ref_table)){
    # $key = filename, $value = wikitext

        open ( FILE, $outfilename ) || die ("you die now!");
            my $outfile= do{local $/; <FILE>;};
        close (FILE);

        # Upload

        print ("Uploading...\n");
        $mw->upload( { title => $outfilename,
                 summary => $wikitext,
                 data => $outfile } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

        print ("Uploaded: http://commons.wikimedia.org/wiki/File%3A$outfilename\n");
        #print ("Text: \n$wikitext\n");

        if (!$autoupload) {
           print ("Please verify that images has uploaded.\n Press 'y' if the upload was good.\n Press 'a' to abort.\n Press 's' to skip this check\n");
        
           ReadMode "cbreak";
           $_ = ReadKey();
           ReadMode "normal";
            
           if(lc $_ eq 'a') { die ("you die now!"); }
           if(lc $_ eq 's') { $autoupload = 1; }
        }
        else {
           print ("Sleeping for $delay seconds\n");
           sleep($delay);
        }
    }
}
