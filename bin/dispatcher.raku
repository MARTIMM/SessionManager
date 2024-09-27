#!/usr/bin/env -S rakudo -Ilib

use v6.d;

%*ENV<IGNORE_GNOME_DEPRECATION_MESSAGES> = 1;

use Desktop::Dispatcher::Application;

#-------------------------------------------------------------------------------
# Initialize global variables

my Str $*dispatcher-version = '0.2.0';
my Array $*local-options = [<version>];
my Array $*remote-options = [ |<config=s v verbose images=s> ];
my Bool $*verbose = False;

my Bool $*dispatch-testing = True;
my Str $*images = 'Images';

my Desktop::Dispatcher::Application $dispatcher .= new;
exit($dispatcher.go-ahead);
