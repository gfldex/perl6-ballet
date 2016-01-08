use v6;
use Ballet;

class AreaCode { ... }
class Letter { ... }

sub index () is dancing {
	Q:to/EOH/	
	<html>
		<head></head>
		<body>
			Hello static world!<br>
			<a href="/simple-named-param/a=10">/simple-named-param</a><br>
			<a href="/named-param-list/a=10;b=10;c=abc">/named-param-list</a><br>
			<a href="/regex-test/a=10;b=10;c=abc">alias test</a><br>
			<a href="/mime-test">/mime-test</a><br>
			<a href="/last-modified-test">/last-modified-test</a><br>
			<a href="/redirection-test">/redirection-test</a><br>
			<a href="/custom-class-test/code=04698;country=Germany">/custom-class-test</a><br>
			<a href="/custom-class-test/code=04698;country=False">false /custom-class-test</a><br>
			<a href="/default-constructor-test/from=Me;to=Her">/default-constructor-test</a><br>
			<a href="/default-constructor-test/from=;to=Her">false /default-constructor-test</a><br>
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

alias /'regex-test'/, &named-param-list;

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

sub custom-class-test ( AreaCode $a ) is dancing {
	$a.perl
}

sub default-constructor-test ( Letter $a ) is dancing {
	$a.perl
}

class AreaCode {
	has Int $.code = Failure.new;
	has Str $.country = Failure.new;

	method new(Int(Str) :$code, Str :$country) {
		$country eq 'Germany' ?? self.bless(:$code, :$country) !! Nil
	}
}

class Letter {
	has Str $.from where /\w+/;
	has Str $.to where /\w+/;
}

server.run;
