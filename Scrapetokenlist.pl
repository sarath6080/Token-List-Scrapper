use File::Compare;
use HTTP::Cookies;
use LWP::UserAgent;
use HTML::Form;
use HTTP::Request;
use LWP::Simple qw(getstore);
use Try::Tiny;
use Date::Parse;
use URI::URL;

$outfile     = "tokenList.json";

my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows NT 6.3; WOW64; rv:47.0) Gecko/20100101 Firefox/47.0");
$ua->timeout(30);
$ua->cookie_jar({});
my $cookie_file = "${packname}_cookie.txt";
unlink($cookie_file);
my $cookie = HTTP::Cookies->new(file=>$cookie_file,autosave=>1);
my $key='verify_hostname';
my $value=0;
$ua->cookie_jar($cookie);
$ua->ssl_opts( $key => $value );

my $res = "";

($Second, $Minute, $Hour, $Day, $Month, $Year, $WeekDay, $DayOfYear, $IsDST) = localtime(time);
$Year +=1900;
$Month++;

&scrape();
#################
# Method scrape()
#################
sub scrape
{
	$success = 0;
	rename($outfile, $lastfile);
	use FileHandle;
	
	my $url = "https://etherscan.io/tokens";
	my $con = Getcontent($url);
	
	$page = $1	if ($con =~ /Page\s*(?:<b>)?\d+(?:<\/b>)?\s*of\s*(?:<b>)?(\d+)(?:<\/b>)?<\/span>/i);
	for ($i=1; $i<=$page; $i++)
	{
		$pgUrl = "https://etherscan.io/tokens?p=$i";
		print "\$pgUrl = $pgUrl\n";

		my $pgCont = Getcontent($pgUrl);
		my $fh = FileHandle->new( "page.html",'>>' ) or die "Cannot open  $outfile";
		binmode($fh);
		$fh->print($pgCont);
		$fh->close();			

		$res .= genVslMovesText($pgCont);
	}
	$res =~ s/^/\[/igs;
	$res =~ s/\,$//igs;
	$res =~ s/$/\]/igs;
	$res =~ s/\]$//igs;
	open(RE,">$outfile");
	print RE "$res";
	close RE;
	print "Total of $i token scrapped\n";
}

###########################
# Method genVslMovesText()
###########################
sub genVslMovesText
{
	my $content = shift;
	my $json = "";
	my $res  = "";
	my ($vslname,$berth,$arrtime,$length,$tonnage);	

	while ($content =~ /<table[\w\W]*?>\s*([\w\W]*?)\s*<\/table>/igs ) 
	{
		my $tr_content = $1;
		while ( $tr_content =~ /<tr[\w\W]*?>\s*([\w\W]*?)\s*<\/tr>/igs ) 
		{
			my $td_content = $1;
	
			$tokenImg = $1 if ($td_content =~ /<img[\w\W]*?src\=\'([\w\W]*?)\'>/is);
			if ($td_content =~ /<h5[\w\W]*?>?<a[\w\W]*?href\=\'\/token\/([\w\W]*?)\'>([\w\W]*?)<\/a>/is)
			{
				$tokenAddr = $1;
				$tokenNme  = $2;
			}
			$json = "\t\t\t{
				"."\""."tokenName"."\"".":"."\""."$tokenNme"."\"".",
				"."\""."address"."\"".":"."\""."$tokenAddr"."\"".",
				"."\""."imageUrl"."\"".":"."\""."$tokenImg"."\""."
				},\n";
			#print "\$json = $json\n";
			if ($tokenNme ne "" )
			{
				$res .= $json;
			}
			undef $tokenNme; undef $tokenAddr; undef $tokenImg;
		}
	}
	return $res
}

###################
# Method trim()
###################
sub trim
{
  my $txt = shift;
  $txt =~ s/[^[:print:]]//ig;
  $txt =~ s/<[^>]*?>\s*/ /g;
  $txt =~ s/@//g;
  $txt =~ s/^\s+|\s+$//g;
  $txt =~ s/\s+/ /g;
  $txt =~ s/\s*\&nbsp\;\s*//g;
  $txt =~ s/\"//g;
  $txt =~ s/&nbsp//g;
  return $txt;
}

######################### To work in the get content link #############################
sub Getcontent
{
	my $url = shift;
	my $rerun_count=0;
	my $redir_url;
	$url =~ s/^\s+|\s+$//g;
	$url =~ s/amp;//igs;
	Home:
	my $req = HTTP::Request->new(GET=>$url);
	# $req->header("Host"=>"");
	# $req->header("Referer"=>"");
	$req->header("Content-Type"=> "text/html; charset=UTF-8");
	my $res = $ua->request($req);
	$cookie->extract_cookies($res);
	$cookie->save;
	$cookie->add_cookie_header($req);
	my $code=$res->code;
	my $status_line=$res->status_line;
	my $File_Type=$res->header("Content-Disposition");
	my $File_Type_cont=$res->header("Content-Type");
	my $content;
	if($code=~m/20/is)
	{		
		$content = $res->content;
	}
	elsif($code=~m/30/is)
	{
		my $loc=$res->header("location");
		if ( $rerun_count<=3)
		{
			$rerun_count++;
			if($loc!~m/http/is)
			{
				my $u1=URI::URL->new($loc,$url);
				my $u2=$u1->abs;
				$url=$u2;
				$redir_url=$u2;
			}
			else
			{
				$url=$loc;
				$redir_url=$loc;
			}
			goto Home;
		}
	}
	else
	{
		if ( $rerun_count <= 3 )
		{
			$rerun_count++;
			sleep 1;
			goto Home;
		}
	}
	return ($content);
}
######################### To work in the post content link #############################
sub Postcontent()
{
	my $post_url=shift;
	my $Post_Content=shift;
	my $Host=shift;
	my $Referer=shift;
	# my $Cookie_JSESSIONID=shift;
	my $rerun_count=0;
	$post_url =~ s/^\s+|\s+$//g;
	$post_url =~ s/amp;//igs;
	Home:
	
	my $req = HTTP::Request->new(POST=>$post_url); 
	$req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
	$req->header("Host"=>"$Host");
	$req->header("Content-Type"=>"application/x-www-form-urlencoded");
	
	$req->content($Post_Content);
	
	
	my $res = $ua->request($req);
	$cookie->extract_cookies($res);
	$cookie->save;
	$cookie->add_cookie_header($req);
	
	my $code=$res->code;
	my $status_line=$res->status_line;
	# my $Content_Disposition=$res->header("Content-Disposition");
	my ($content,$redir_url);
	if($code=~m/20/is)
	{
		$content = $res->content;
	}
	elsif($code=~m/30/is)
	{
		my $loc=$res->header("location");
		$redir_url=$loc;
		if($rerun_count <= 3)
		{
			my $u1=URI::URL->new($loc,$post_url);
			my $u2=$u1->abs;
			# $Content_Disposition=$u2;
			my $Redir_url=$u2;
			($content,$Redir_url)=&Getcontent($u2);
		}
	}
	else 
	{
		if($rerun_count <= 1)
		{
			$rerun_count++;
			sleep 1;
			goto Home;
		}
	}
	return ($content);
}
#########################################
#To Convert Pdf file to word
##########################################
sub ConvertPdftoWord()
{
	# $Convoutfile = shift;
	
	# my $outfile_html = $Convoutfile;
	
	# $outfile_html =~ s/\.(docx?|pdf)\s*$/.html/igs;
	
	system("$ENV{'DATALOAD_ETA_SCRAPE_ARCHIVE_PATH'}\\XPDF\\cpdf.exe -scale-to-fit a4portrait \"$outfile\" -o \"$reszdPdf\"");

	eval {$word = Win32::OLE->GetActiveObject('Word.Application')};
	die "Word not installed" if $@;
	unless (defined $word) {
	$word = Win32::OLE->new('Word.Application', sub { $_[0]->Quit; })
		or die "Cannot start Word";
	}

	$word->{Visible} = 0 ;
	$word->{DisplayAlerts} = 0 ;
   
	Win32::OLE->Option(Warn => 3);
	my $doc = $word->{'Documents'}->Open("$reszdPdf");
	# Save in .doc and .html formats
	$doc->SaveAs( { Filename => $outfile_html, FileFormat => 8 } );
	$doc->Close();
	undef $doc;
	undef $word;
	
	# if ( -e $outfile_html )
	# {
		# $out .= &genVslMovesText1($outfile_html);
	# }
}

