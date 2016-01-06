use v6;
use Ballet;

sub index () is dancing {
	Q:to/EOH/	
	<html>
		<head></head>
		<body>
			Hello static world!<br>
			<a href="/simple-named-param/a=10">/simple-named-param</a><br>
			<a href="/named-param-list/a=10;b=10;c=abc">/named-param-list</a><br>
			<a href="/mime-test">/mime-test</a><br>
			<a href="/last-modified-test">/last-modified-test</a><br>
			<a href="/redirection-test">/redirection-test</a><br>
		</body>
	</html>
	EOH
}

sub simple-named-param (Int :$a) is dancing {
	Q:c:to/EOH/
	<html>
		<head></head>
		<body>
			a: {$a}	
		</body>
	</html>
	EOH
}

sub named-param-list ( Int :$a, Int :$b, Str :$c where /abc/ ) is dancing {
	($a, $b, $c).perl
}

sub mime-test () is dancing is mime('text/text') {
	'Hello ASCII-World!',
	&?ROUTINE.WHAT
}

sub last-modified-callback ($d? --> DateTime) {
	DateTime.now.earlier(day => 1);
}

sub last-modified-test () is dancing is last-modified(&last-modified-callback) {
	'I was last modified: ',
	&?ROUTINE.last-modified.(&?ROUTINE).Str
} 

sub redirection-test () is redirecting {
	'https://www.youtube.com/watch?v=HVFNn_JwKhU'
}

server.run;
