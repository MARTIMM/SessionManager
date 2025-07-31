#!/usr/bin/env -S rakudo -Ilib

use v6.d;

#%*ENV<IGNORE_GNOME_DEPRECATION_MESSAGES> = 1;

use SessionManager::Gui::Application;

#-------------------------------------------------------------------------------
# Initialize global variables

my Version $*manager-version = v0.5.0;
my Bool $*verbose = False;

my $*dispatch-testing = False;

my Str $*images = 'Images';


my SessionManager::Gui::Application $dispatcher .= new;
exit($dispatcher.go-ahead);
