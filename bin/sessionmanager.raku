#!/usr/bin/env -S rakudo -Ilib

use v6.d;

#%*ENV<IGNORE_GNOME_DEPRECATION_MESSAGES> = 1;

use SessionManager::Gui::Application;

#-------------------------------------------------------------------------------
# Initialize global variables

my Str $*dispatcher-version = '0.4.6';
my Array $*local-options = [<version>];
my Array $*remote-options = [ |<config=s v verbose images=s legacy> ];
my Bool $*verbose = False;

my $*dispatch-testing = False;

my Str $*images = 'Images';


my SessionManager::Gui::Application $dispatcher .= new;
exit($dispatcher.go-ahead);
