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
      running run-log run-error get-new-log-lines tap
      >;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$id is copy ) {
  my Desktop::Dispatcher::Actions $actions .= instance;
  $!action-data = $actions.get-action($id);
  if ! $!action-data {
    # If action data isn't found, try iot is if it was a tooltip string
    # Those are taken when no id was found and converted into shs256
    # strings in Desktop::Dispatcher::ActionData.
    $id = sha256-hex($id);
    $!action-data = $actions.get-action($id);
  }

  die "Failed to find an action with id '$id'" unless ?$!action-data;
}

#-------------------------------------------------------------------------------
method execute ( ) {
  $!action-data.run-action;
}
