v6.d;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Sessions;

constant ConfigPath = '/Config/sessions.yaml';
my SessionManager::Gui::Variables $instance;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!variables = %();
  $!temporary = %();
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Sessions ) {
  $instance //= self.bless;

  $instance
}

