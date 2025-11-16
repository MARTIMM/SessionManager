use v6.d;

use SessionManager::ActionData;

use Digest::SHA256::Native;
use YAMLish;

#-------------------------------------------------------------------------------
unit class SessionManager::Actions;

constant ConfigPath = '/Config/actions.yaml';

my Hash $data-ids = %();

#-------------------------------------------------------------------------------
method add-action ( Hash:D $raw-action, Str :$id = '' --> Str ) {
  my SessionManager::ActionData $action-data;
  $action-data .= new;
  $action-data.init-action( :$raw-action, :$id);
  $data-ids{$action-data.id} = %(
    :data($action-data),
    :depend([])
  );
  $action-data.id
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
method save ( ) {
  my Hash $raw-actions = %();
  for $data-ids.keys -> $id {
    $raw-actions{$id} = $data-ids{$id}<data>.raw-action;
  }

  ($*config-directory ~ ConfigPath).IO.spurt(save-yaml($raw-actions));
}

#-------------------------------------------------------------------------------
method load ( ) {
  if ($*config-directory ~ ConfigPath).IO.r {
    my Hash $raw-actions = load-yaml(
      ($*config-directory ~ ConfigPath).IO.slurp
    );

    for $raw-actions.keys -> $id {
      self.add-action( $raw-actions{$id}, :$id);
    }
  }
}

#-------------------------------------------------------------------------------
method get-action-ids ( --> Seq ) {
  $data-ids.keys
}

#-------------------------------------------------------------------------------
method get-raw-action ( Str:D $action-id --> Hash ) {
  $data-ids{$action-id}<data>.raw-action
}

#-------------------------------------------------------------------------------
method get-action ( Str:D $id is copy --> SessionManager::ActionData ) {
  if $data-ids{$id}:exists {
    $data-ids{$id}<data>
  }

  else {
#`{{
    # If action data isn't found, try $id as if it was a tooltip
    # string. Those are taken when no id was found and converted into sha256
    # strings in SessionManager::ActionData.
    $id = sha256-hex($id);
    if $data-ids{$id}:exists {
      $data-ids{$id}
    }

    else {
}}
      SessionManager::ActionData
#    }
  }
}

#-------------------------------------------------------------------------------
method rename-action ( Str:D $id, Str:D $new-id ) {
  $data-ids{$new-id} = $data-ids{$id}:delete;
  $data-ids{$new-id}.modify-id($new-id);
}
 
#-------------------------------------------------------------------------------
method modify-action ( Str:D $id, Hash $raw-action ) {
  my SessionManager::ActionData $action-data = $data-ids{$id}<data>;
  $action-data.init-action( :$id, :$raw-action);
}

#-------------------------------------------------------------------------------
# Substitute changed variable in the raw actions Hash.
method subst-vars ( Str $original-var, Str $new-var ) {
  for $data-ids.keys -> $id {
    $data-ids{$id}<data>.subst-vars( $original-var, $new-var);
  }
}

#-------------------------------------------------------------------------------
method is-var-in-use ( Str $v --> Bool ) {
  my Bool $in-use = False;
  for $data-ids.keys -> $id {
    $in-use = $data-ids{$id}<data>.is-var-in-use($v);
    last if $in-use;
  }

  $in-use
}
