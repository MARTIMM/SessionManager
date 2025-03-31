use v6.d;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::ActionData;

has Bool $!skip-group-run;

has Str $!tooltip;
has Str $!workdir;
has $!env;
has Str $!script;
has Str $!cmd;
has Str $!picture;
has Str $!overlay-picture;

has $!temp-variables;
has $!variables;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
}

#-------------------------------------------------------------------------------

