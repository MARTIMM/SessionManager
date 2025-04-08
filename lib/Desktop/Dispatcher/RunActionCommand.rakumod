use v6.d;

use Desktop::Dispatcher::ActionData;
use Desktop::Dispatcher::Actions;
use Desktop::Dispatcher::Command;

use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::RunActionCommand;
also is Desktop::Dispatcher::Command;

#-------------------------------------------------------------------------------
has Desktop::Dispatcher::ActionData $!action-data handles <
      running run-log run-error tap
      >;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$id ) {
  my Desktop::Dispatcher::Actions $actions .= instance;
  $!action-data = $actions.get-action($id);
  die "Failed to find an action with id '$id'" unless ?$!action-data;
}

#-------------------------------------------------------------------------------
method execute ( ) {
  $!action-data.run-action;
}
