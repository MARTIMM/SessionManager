
use v6.d;
use NativeCall;

use SessionManager::Gui::Actions;
use SessionManager::Gui::Variables;
use SessionManager::Gui::Sessions;
use SessionManager::Gui::Config;

use Gnome::Gio::Menu:api<2>;
use Gnome::Gio::MenuItem:api<2>;
use Gnome::Gio::SimpleAction:api<2>;

use Gnome::Gtk4::Button:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::MenuBar:auth<github:MARTIMM>;

has Gnome::Gio::Menu $.bar;
has $!application is required;
has $!main is required;

has Array $!menus;
has SessionManager::Gui::Actions $!action-edit;
has SessionManager::Gui::Variables $!variable-edit;
has SessionManager::Gui::Sessions $!session-edit;
has SessionManager::Gui::Config $!config-edit;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!application = $!main.application;
  $!action-edit .= instance;
  $!variable-edit .= instance;
  $!session-edit .= instance;
  $!config-edit .= instance;

  $!bar .= new-menu;
  $!menus = [
    self.make-menu( :menu-name<File>, :shortcut),
    self.make-menu( :menu-name<Sessions>, :shortcut),
    self.make-menu( :menu-name<Actions>, :shortcut),
    self.make-menu( :menu-name<Variables>, :shortcut),
  ];
}

#-------------------------------------------------------------------------------
method make-menu (
  Str :$menu-name, Bool :$shortcut = False --> Gnome::Gio::Menu
) {
  my Gnome::Gio::Menu $menu .= new-menu;
  $!bar.append-submenu( $shortcut ?? "_$menu-name" !! "$menu-name", $menu);

#  my PuzzleTable::Config $config = $!main.config;

  with $menu-name {
    when 'File' {
      # Prepare a section
      my Gnome::Gio::Menu $section-menu .= new-menu;
      self.bind-action(
        $section-menu, $menu-name, $!config-edit, 'Modify Configuration',
      );

      self.bind-action( $section-menu, $menu-name, self, 'Restart');
      $menu.append-section( Str, $section-menu);


      $section-menu .= new-menu;
      self.bind-action( $section-menu, $menu-name, self, 'Quit');
      $menu.append-section( Str, $section-menu);
    }

    when 'Sessions' {
      self.bind-action( $menu, $menu-name, $!session-edit, 'Add/Rename');

      self.bind-action(
        $menu, $menu-name, $!session-edit, 'Add/Rename Group'
      );

      self.bind-action(
        $menu, $menu-name, $!session-edit, 'Delete Group'
      );

      self.bind-action(
        $menu, $menu-name, $!session-edit, 'Add/Remove Actions'
      );

      self.bind-action( $menu, $menu-name, $!session-edit, 'Delete');
    }

    when 'Actions' {
      self.bind-action( $menu, $menu-name, $!action-edit, 'Create');
      self.bind-action( $menu, $menu-name, $!action-edit, 'Modify');
      self.bind-action( $menu, $menu-name, $!action-edit, 'Rename id');
      self.bind-action( $menu, $menu-name, $!action-edit, 'Delete');
    }

    when 'Variables' {
      self.bind-action( $menu, $menu-name, $!variable-edit, 'Add Modify');
      self.bind-action( $menu, $menu-name, $!variable-edit, 'Delete');
    }
  }

  $menu
}

#-------------------------------------------------------------------------------
method bind-action (
  Gnome::Gio::Menu $menu, Str $menu-name, Mu $object, Str $entry-name,
  Bool :$shortcut = False
) {

  # Make a method and action name
  my Str $method = [~] $menu-name, ' ', $entry-name;
  $method .= lc;
  $method ~~ s:g/ <[\s/_]>+ /-/;

  my Str $action-name = 'app.' ~ $method;

  # Make a menu entry
  my Gnome::Gio::MenuItem $menu-item .= new-menuitem(
    $shortcut ?? "_$entry-name" !! $entry-name, $action-name
  );
  $menu.append-item($menu-item);

  # Use the method name
  my Gnome::Gio::SimpleAction $action .= new-simpleaction( $method, Pointer);
  $!application.add-action($action);
  $action.register-signal( $object, $method, 'activate');
}

#-------------------------------------------------------------------------------
method file-restart ( N-Object $parameter ) {
  say 'file restart';
  $!main.restart;
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  say 'file quit';
  $!application.quit;
}

