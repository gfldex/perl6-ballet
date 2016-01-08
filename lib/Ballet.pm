unit module Ballet;

use HTTP::Server::Simple;

my &debug := &note;
my $default-content-type = 'text/html';
my $dont-overwrite = False;

role Dancer[ $mime-type = $default-content-type ] is export {
    has $.returns-mime is rw = $mime-type;
    has $.last-modified is rw = sub (&r where Dancer) { DateTime.now };
}

role Redirector[ $url = '/not-found-404' ] is export {
    has $.url is rw = $url;
}
class X::Ballet is Exception {};

class X::Ballet::NamedArgumentMismatch is X::Ballet {
    has Str $.dancer;
    has Str $.named-argument-name;
    method message(){ "Could not find argument: $.named-argument-name in $.dancer" }
}

class X::Ballet::FailedConstructor is X::Ballet {
    has Str $.dancer;
    has Str $.type;
    has Str $.arguments;
    method message(){ "Could not create $.type with $.arguments in $.dancer" }
}

class X::Ballet::NilCapture is X::Ballet {
    has Str $.dancer;
    has Str $.capture;
    has Str $.uri;
    method message() { "Found Nil in $.capture for $.uri in $.dancer" }
}

my %aliases{Regex};

my %handlers{Str} = # Str $matcher => Dancer|Redirector &routine
### Predefined Dancers
# We have to mixin the role by hand because the trait isn't available until the module has been compiled (or somesuch).

not-found_404 => sub not-found_404 () {
    "===SORRY===\nCamelia could not find your page"
} does Dancer,
# TODO disable the following or provide option
debug-dancer => sub debug-dancer () {
    '<html><body>'
    ~ %handlers.pairs.map('<pre>' ~ *.gist ~ '</pre>' ) ~  '<br><br>' ~ %aliases.pairs.map('<pre>' ~ *.gist ~ '</pre>')
    ~ '</body></html>'
} does Dancer,
'/' => sub root () { 
    '/index' 
} does Redirector 
;

multi sub trait_mod:<is>(Routine $r, :$dancing!) is export {
    debug "add dancer {$r.name}";
    $r does Dancer;
    die "please don't overwrite Dancer {$r.name}" if $dont-overwrite && (%handlers{$r.name}:exists);
    warn "overwriting dancer {$r.name}" if %handlers{$r.name}:exists;
    %handlers{$r.name} = $r;
}

multi sub trait_mod:<is>(Dancer $r, :$mime!) is export {
    debug "set mime for {$r.name} to $mime";
    $r.returns-mime = $mime; 
#    X::NYI.new(:feature("is mime")).throw;
}

multi sub trait_mod:<is>(Dancer $r, Callable :$last-modified!) is export {
    die "callback for last-modified needs to have the signature :(Dancer &r --> DateTime)" 
    unless $last-modified.signature.returns ~~ DateTime;

    debug "add last-modified callback for {$r.name}";
    $r.last-modified = $last-modified;
}

multi sub trait_mod:<is>(Routine $r, :$redirecting) is export {
# TODO match against URL or if Dancer of that name exists
    debug "register redirector";
    $r does Redirector;
    %handlers{$r.name} = $r;
}

sub alias (Regex $matcher, &r where * ~~ Dancer) is export {
    %aliases{$matcher} = &r;
}

my class HTTP::Server is HTTP::Server::Simple {
    has $!uri;

    method new ($host, $port){
        self.bless( self.CREATE(), port => $port, host => $host // self.lookup_localhost );
    }

    method handle_request () {
        debug "handling URL: $!uri";
        my $method = $!uri.split('/')[1] || '/';
        debug "handling method: «$method»";
        my $dancer = %handlers{$method};
        my @positionals;
        my %named;
        my $capture = [];
        with $dancer {
            when Redirector {
                my $location = $dancer();
                debug "redirecting to { $location } ";
                print "HTTP/1.1 307 See Other\x0D\x0A";
                print "Location: { $location }\x0D\x0A";
                print "\x0D\x0A";
                print "please go to: { $location }\x0D\x0A";
            }
            when Dancer {
                try {
                    for $!uri.split('/')[2..*] {
                        for .split(';') {
                            if (my @parts = .split('=')).elems > 1 {
                                %named.push(@parts[0], @parts[1]); # This will change the value to a list if named arguments occur twice or more.
                            } else {
                                @positionals.push: |(.item);
                            }
                        }

                        my int $param-counter = 0;
                        my int $positionals-counter = 0;
                        for $dancer.signature.params {
                            when .positional {
                                my $type-name = .type.perl;
                                if .type ~~ Cool { # Cool provides copy constructors from Str
                                    $capture[$param-counter++] := .type.new(@positionals[$positionals-counter]);
                                } else {
                                    try { 
                                        $capture[$param-counter++] := .type.new(|%named); 

                                        CATCH {
                                            when X::TypeCheck::Assignment {
                                                X::Ballet::FailedConstructor.new(dancer=>$dancer.name, type=>$type-name, arguments=>%named.perl).throw;
                                            }
                                        }
                                    }
                                    last;
                                }
                                $positionals-counter++;
                            }
                            when .named {
                                my $type-name = .type.perl;
                                debug %named, @positionals;
                                X::Ballet::NamedArgumentMismatch.new(named-argument-name=>.name,dancer=>$dancer.name).throw
                                unless %named{.name.substr(1)}:exists;
                                my $pair = %named{.name.substr(1)}:p;
                                if .type ~~ Cool {
                                    $pair.value = .type.($pair.value);
                                } else {
                                    try { 
                                        $pair.value = .type.new($pair.value);

                                        CATCH {
                                            when X::TypeCheck::Assignment {
                                                X::Ballet::FailedConstructor.new(dancer=>$dancer.name, type=>$type-name, arguments=>%named.perl).throw;
                                            }
                                        }
                                    } 
                                }
                                $capture[$param-counter++] := $pair;
                            }
                            when .capture {
                                X::NYI.new(feature => 'capture parameters on dancers').throw;
                            }
                            $param-counter++;
                        }
                        last; # one run loop to the the topic set and time to think what multiple sets or parameters mean (call multiple Dancers in one go for webapi stuff?)
                    }

                    X::Ballet::NilCapture.new(dancer => $dancer.name, uri => $!uri, capture => $capture.perl).throw
                    if Nil === any($capture.flat);

                    my $content-type = $dancer.returns-mime;
                    print "HTTP/1.0 200 OK\x0d\x0a";
                    print "Content-Type: $content-type\x0d\x0a";
                    with .last-modified.($dancer).utc {
                        my $last-modified = sprintf(
                            '%s, %02d %s %04d %02d:%02d:%02d GMT', 
                            <- Mon Tue Wed Thu Fri Sat Sun>[.day-of-week],
                            .day, 
                            <- Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec>[.month],
                            .year,
                            .hour,
                            .minute,
                            .second
                        );
                        print "Last-Modified: $last-modified\x0D\x0A";
                    }   
                    print "\x0d\x0a";
                    print $dancer.(|$capture.Capture), "\x0d\x0a";

                    CATCH {
                        when X::Ballet {
                            debug .message;
                            print "HTTP/1.0 400 Invalid Argument\x0d\x0a"; 
                            print "\x0D\x0A";
                            print "Invalid Argument\x0D\x0A";

                        }
                    }
                }
            }
        } else {
            print "HTTP/1.0 404 Not Found\x0D\x0A";
            print "Content-Type: text/text\x0D\x0A";
            print "\x0D\x0A";
            %handlers<not-found_404>.();
            note "404 $method";
        }
    }

    method setup ( :$method, :$protocol, :$request_uri, :$path, :$query_string, :$localport, :$peername, :$peeraddr, :$localname ) {
        $!uri = $request_uri;
    }
}

my $server;

sub server () is export { $server }

INIT {
    $server = HTTP::Server.new('', 8080);
}

# vim: expandtab shiftwidth=4 ft=perl6
