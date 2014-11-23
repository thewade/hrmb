use MediaWiki::API;
use Set::IntSpan::Fast;
use Getopt::Long;

GetOptions(
    'category=s'   => \$catagory,
    'range=s'      => \$range,
    'help'         => \$help,
) or die "Incorrect usage!\n";

if ($help) {
 print "Example: getmissing.pl --category=\"Elongated circular route shields\" --range=\"0-9000\"\n";
 exit;
}

my $mw = MediaWiki::API->new();
$mw->{config}->{api_url} = 'http://commons.wikimedia.org/w/api.php';

# get a list of articles in category
my $articles = $mw->list ( {
action => 'query',
list => 'categorymembers',
cmtitle => "Category:$catagory",
cmlimit => 'max' } )
	|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

# and print the article titles
foreach (@{$articles}) {
	$title = "$_->{title}";
	if ($title =~ /\s(\d*)\W/) {
		$number = $1;
		push (@numbers, $number);
		#print "$title ($number)\n";
	}
	elsif ($title =~ /(\w*\d\w*)/){
		$other = $1;
		push (@others, $other);
		#print "$title ($other)\n";
	}
	else {
		print "ERROR - how did I get here? ($title)\n";
		$number = "";
		$other = "";
	}
	#print "$title ($number)\n";
}

my $all = Set::IntSpan::Fast->new($range);
my $found = Set::IntSpan::Fast->new(@numbers);
my $missing = $all->diff($found);

print "Found set: ". $found->as_string() ."\n";
print "Missing set: ". $missing->as_string() ."\n";
print "Others found: ";
foreach (@others) {
	print "$_,";
}
print "\nTotal missing: " . scalar $missing->as_array() ."\n";

