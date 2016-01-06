use v6;
use Ballet;
use Test;

plan 3;

ok try { sub index () is dancing { '<html><body></body></html>' } }
    , 'We can trait as dancing.';

ok try { sub mime () is dancing is mime('text/text') { 'text' } }
    , 'We can trait as mime.';

sub callback (&d? --> DateTime) { DateTime.now }

ok try { sub modified is dancing is last-modified(&callback) { } }
    , 'We can trait as last-modified.';

# vim: expandtab shiftwidth=4 ft=perl6
