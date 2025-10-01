use v6.d;

use SessionManager::ActionData;
use SessionManager::Actions;
use SessionManager::Command;

use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class SessionManager::RunActionCommand;
also is SessionManager::Command;

#-------------------------------------------------------------------------------
has SessionManager::ActionData $!action-data handles <
      running run-log run-error tap tooltip picture overlay-picture
      cmd-logging cmd-finish-wait
    >;
      # cmd-background

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$id ) {
  my SessionManager::Actions $actions .= new;
  $!action-data = $actions.get-action($id);
  die "Failed to find an action with id '$id'" unless ? $!action-data;
}

#-------------------------------------------------------------------------------
method execute ( ) {
  $!action-data.run-action;
}
