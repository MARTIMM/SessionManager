use v6.d;

use Desktop::Dispatcher::ActionData;

use Digest::SHA256::Native;
use YAMLish;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Actions;

#-------------------------------------------------------------------------------
my $instance;

has Hash $!data-ids;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!data-ids = %();
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> Desktop::Dispatcher::Actions ) {
  $instance //= self.bless;

  $instance
}

#-------------------------------------------------------------------------------
method add-action ( Hash:D $raw-action, Str :$id is copy ) {
  my Desktop::Dispatcher::ActionData $action-data;
  if ? $id {
    $action-data .= new( :$raw-action, :$id);
    $!data-ids{$id} = $action-data;
  }

  else {
    $action-data .= new(:$raw-action);
    $!data-ids{$action-data.id} = $action-data;
  }
}

#-------------------------------------------------------------------------------
# Only in action reference files
multi method add-actions ( Hash:D $raw-actions ) {
  for $raw-actions.keys -> $id {
    self.add-action( $raw-actions{$id}, :$id);
  }
}

#-------------------------------------------------------------------------------
# Only found in config file and parts files
multi method add-actions ( Array:D $raw-actions ) {
  for @$raw-actions -> $action {
    self.add-action($action);
  }
}

#-------------------------------------------------------------------------------
# Read from action reference files
method add-from-yaml ( Str:D $path ) {
  die "File $path not found or unreadable" unless $path.IO.r;

  self.add-actions(load-yaml($path.IO.slurp));
}

#-------------------------------------------------------------------------------
method get-action ( Str:D $id is copy --> Desktop::Dispatcher::ActionData ) {
  if $!data-ids{$id}:exists {
    $!data-ids{$id}
  }

  else {
    # If action data isn't found, try $id as if it was a tooltip
    # string. Those are taken when no id was found and converted into sha256
    # strings in Desktop::Dispatcher::ActionData.
    $id = sha256-hex($id);
    if $!data-ids{$id}:exists {
      $!data-ids{$id}
    }

    else {
      Desktop::Dispatcher::ActionData
    }
  }
}
