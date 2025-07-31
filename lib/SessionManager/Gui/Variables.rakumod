use v6.d;

use YAMLish;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Variables;

constant ConfigPath = '/Config/variables.yaml';

my SessionManager::Gui::Variables $instance;

has Hash $!variables;
has Hash $!temporary;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!variables = %();
  $!temporary = %();
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Variables ) {
  $instance //= self.bless;

  $instance
}

#-------------------------------------------------------------------------------
method add ( Hash:D $variables ) {
  $!variables = %( | $!variables, | $variables);
}

#-------------------------------------------------------------------------------
method add-from-yaml ( Str:D $path ) {
  die "File $path not found or unreadable" unless $path.IO.r;
  $!variables = %( | $!variables, | load-yaml($path.IO.slurp));
}

#-------------------------------------------------------------------------------
method save ( ) {
  ($*config-directory ~ ConfigPath).IO.spurt(save-yaml($!variables));
}

#-------------------------------------------------------------------------------
method set-temporary ( Hash:D $!temporary ) { }

#-------------------------------------------------------------------------------
method substitute-vars ( Str $t --> Str ) {

  my Str $text = $t;

  while $text ~~ m/ '$' $<variable-name> = [<alpha> | \d | '-']+ / {
    my Str $name = $/<variable-name>.Str;

    # Look in the variables Hash
    if $!variables{$name}:exists {
      $text ~~ s:g/ '$' $name /$!variables{$name}/;
    }

    # Look in the temporary Hash
    elsif $!temporary{$name}:exists {
      $text ~~ s:g/ '$' $name /$!temporary{$name}/;
    }

    # Look in the environment
    elsif %*ENV{$name}:exists {
      $text ~~ s:g/ '$' $name /%*ENV{$name}/;
    }

    # Fail and block variable by substituting $ for __
    else {
      note "No substitution yet or variable \$$name" if $*verbose;
      $text ~~ s:g/ '$' $name /___$name/;
    }
  }

  # Not substituted names are replaced by the original variable format
  $text ~~ s:g/ '___' ([<alpha> | <[0..9]> | '-']+) /\$$0/;

  $text
}

#-------------------------------------------------------------------------------
# Calls from menubar entries
#-------------------------------------------------------------------------------
method variables-add ( N-Object $parameter ) {
  note "$?LINE";

  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Create Action')
  ) {

    
#`{{
    my Str $current-root = $!config.get-current-root;

    # Make a string list to be used in a combobox (dropdown)
    my GnomeTools::Gtk::DropDown $container-dd .= new;
    $container-dd.fill-containers(
      $!config.get-current-container, $current-root, :skip-default
    );

    my GnomeTools::Gtk::DropDown $roots-dd;
    if $*multiple-roots {
      $roots-dd .= new;
      $roots-dd.fill-roots($!config.get-current-root);

      # Show dropdown
      .add-content( 'Select a root', $roots-dd);

      # Set a handler on the container list to change the category list
      # when an item is selected.
      $roots-dd.trap-root-changes( $container-dd, :skip-default);
    }

    # Show entry for input
    .add-content( 'Select container to delete', $container-dd);

    # Buttons to delete the container or cancel
    .add-button(
      self, 'do-container-delete', 'Delete',
      :$dialog, :$container-dd, :$roots-dd
    );
    .add-button( $dialog, 'destroy-dialog', 'Cancel');
}}

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-add-variable (
  GnomeTools::Gtk::Dialog :$dialog,
  GnomeTools::Gtk::DropDown :$container-dd,
  GnomeTools::Gtk::DropDown :$roots-dd
) {
  my Bool $sts-ok = False;
  my Str $root-dir;


#`{{
  if $*multiple-roots {
    $root-dir = $roots-dd.get-dropdown-text;
  }

  else {
    $root-dir = $!config.get-current-root;
  }

  my Str $container = $container-dd.get-dropdown-text;
  if not $!config.delete-container( $container, $root-dir) {
    $dialog.set-status("Container $container not empty");
  }

  else {
    $!sidebar.fill-sidebar;
    $sts-ok = True;
  }
}}

  $dialog.destroy-dialog if $sts-ok;
}


#-------------------------------------------------------------------------------
method variables-modify ( N-Object $parameter ) {
  note "$?LINE";
}

#-------------------------------------------------------------------------------
method variables-delete ( N-Object $parameter ) {
  note "$?LINE";
}

