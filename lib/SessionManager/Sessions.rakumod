v6.d;

use YAMLish;

#-------------------------------------------------------------------------------
unit class SessionManager::Sessions;

my constant ConfigPath = '/Config/sessions.yaml';

my Hash $sessions = %();

#-------------------------------------------------------------------------------
method load-session ( Str:D $name, Str:D $path ) {
  $sessions{$name} = load-yaml($path.IO.slurp);
}

#-------------------------------------------------------------------------------
method add-session ( Str:D $name, Hash:D $session ) {
  $sessions{$name} = $session;
}

#-------------------------------------------------------------------------------
method get-session-ids ( --> Seq ) {
  $sessions.keys
}

#-------------------------------------------------------------------------------
method get-session ( Str:D $sid, Bool :$delete = False --> Hash ) {
  if $delete {
    $sessions{$sid}:delete
  }

  else {
    $sessions{$sid}
  }
}

#-------------------------------------------------------------------------------
method set-session ( Str:D $sid, Hash:D $session ) {
  $sessions{$sid} = $session;
}

#-------------------------------------------------------------------------------
method get-session-title ( Str:D $sid --> Str ) {
  $sessions{$sid}<title> // ''
}

#-------------------------------------------------------------------------------
method set-session-title ( Str:D $sid, Str $title = '' ) {
  $sessions{$sid}<title> = $title;
}

#-------------------------------------------------------------------------------
method get-session-icon ( Str:D $sid --> Str ) {
  $sessions{$sid}<icon> // ''
}

#-------------------------------------------------------------------------------
method set-session-icon ( Str:D $sid, Str $icon = '' ) {
  $sessions{$sid}<icon> = $icon;
}

#-------------------------------------------------------------------------------
method get-session-overlay ( Str:D $sid --> Str ) {
  $sessions{$sid}<over> // ''
}

#-------------------------------------------------------------------------------
method set-session-overlay ( Str:D $sid, Str $overlay = '' ) {
  $sessions{$sid}<over> = $overlay;
}

#-------------------------------------------------------------------------------
method rename-session ( Str:D $sid, Str:D $new-sid ) {
  $sessions{$new-sid} = $sessions{$sid}:delete;
}

#-------------------------------------------------------------------------------
method get-sessions ( --> Hash ) {
  $sessions
}

#-------------------------------------------------------------------------------
method add-group ( Str:D $sid, Str $grouptitle = '' --> Str ) {
  my Str $group-id;

  # Add a group key. names are labeled: group1, group2, etc. with a maximum of 5
  for 1..6 -> $group-count {
    if $group-count >= 10 {
      # Finish and return undefined string
      last;
    }

    my Str $new-group = "group$group-count";
    next if $sessions{$sid}{$new-group}:exists;

    # Add a new group, set its title and add an actions key
    $sessions{$sid}{$new-group}<title> = $grouptitle;
    $sessions{$sid}{$new-group}<actions> = [];
    $group-id = $new-group;
    last;
  }

  $group-id
}

#-------------------------------------------------------------------------------
method group-exists ( Str:D $sid, Str:D $group-id --> Bool ) {
  $sessions{$sid}{$group-id}:exists;
}

#-------------------------------------------------------------------------------
method get-group-ids ( Str:D $sid --> Seq ) {
  $sessions{$sid}.keys.grep(/^group/)
}

#-------------------------------------------------------------------------------
method get-group-title ( Str:D $sid, Str:D $group-id --> Str ) {
  $sessions{$sid}{$group-id}<title> // ''
}

#-------------------------------------------------------------------------------
method set-group-title ( Str:D $sid, Str:D $group-id, Str $title = '' ) {
  $sessions{$sid}{$group-id}<title> = $title;
}

#-------------------------------------------------------------------------------
method get-group-actions ( Str:D $sid, Str:D $group-id --> Array ) {
  $sessions{$sid}{$group-id}<actions> // []
}

#-------------------------------------------------------------------------------
multi method set-group-actions (
  Str:D $sid, Str:D $group-id, Array $actions = []
) {
  $sessions{$sid}{$group-id}<actions> = $actions;
}

#-------------------------------------------------------------------------------
multi method set-group-actions ( Str:D $sid, Str:D $group-id, Str $action ) {
  $sessions{$sid}{$group-id}<actions>.push: $action;
}

#-------------------------------------------------------------------------------
method rename-group-actions ( Str:D $old-aid, Str:D $new-aid ) {
  for $sessions.keys -> $sid {
    for $sessions{$sid}.keys.grep(/^group/) -> $group-id {
      my Array $actions = $sessions{$sid}{$group-id}<actions>;
      loop ( my Int $i = 0; $i < $actions.elems; $i++ ) {
        if $actions[$i] eq $old-aid {
          $actions[$i] = $new-aid;
          $sessions{$sid}{$group-id}<actions> = $actions;
          last;
        }
      }
    }
  }
}

#-------------------------------------------------------------------------------
method is-action-in-use ( Str:D $aid --> Bool ) {
  my Bool $in-use = False;

  for $sessions.keys -> $sid {
    for $sessions{$sid}.keys.grep(/^group/) -> $group-id {
      my Array $actions = $sessions{$sid}{$group-id}<actions>;
      loop ( my Int $i = 0; $i < $actions.elems; $i++ ) {
        if $actions[$i] eq $aid {
          $in-use = True;
          last;
        }
      }
    }

    last if $in-use;
  }

  $in-use
}

#-------------------------------------------------------------------------------
method is-var-in-use ( Str $v --> Bool ) {
  my Bool $in-use = False;

  for $sessions.kv -> $k, $text {
    if $text ~~ m/ '$' $v <-[\w-]>? / {
      $in-use = True;
      last;
    }
  }

  $in-use
}

#-------------------------------------------------------------------------------
method save ( ) {
  ($*config-directory ~ ConfigPath).IO.spurt(save-yaml($sessions));
}

#-------------------------------------------------------------------------------
method load ( ) {
  if ($*config-directory ~ ConfigPath).IO.r {
    $sessions = load-yaml(($*config-directory ~ ConfigPath).IO.slurp);
  }
}

