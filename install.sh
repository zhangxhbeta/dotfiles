#!/usr/bin/env bash

###########################
# This script installs the dotfiles and runs all other system configuration scripts
# @author Adam Eivy and me, Xiaohui Zhang
###########################

# include my library helpers for colorized echo and require_brew, etc
source ./lib_sh/echos.sh
source ./lib_sh/requirers.sh

# Disable homebrew autoupdate
export HOMEBREW_NO_AUTO_UPDATE=1

# Proxy through socks
export socks5_proxy=socks5://127.0.0.1:1086
export http_proxy=http://127.0.0.1:1087
export https_proxy=http://127.0.0.1:1087

bot "Hi! I'm going to install tooling and tweak your system settings. Here I go..."

# Ask for the administrator password upfront
if ! sudo grep -q "%wheel		ALL=(ALL) NOPASSWD: ALL #atomantic/dotfiles" "/etc/sudoers"; then

  # Ask for the administrator password upfront
  bot "I need you to enter your sudo password so I can install some things:"
  sudo -v

  # Keep-alive: update existing sudo time stamp until the script has finished
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

grep 'user = GITHUBUSER' ./homedir/.gitconfig > /dev/null 2>&1
if [[ $? = 0 ]]; then
    read -r -p "What is your github.com username? " githubuser

  fullname=`osascript -e "long user name of (system info)"`

  if [[ -n "$fullname" ]];then
    lastname=$(echo $fullname | awk '{print $2}');
    firstname=$(echo $fullname | awk '{print $1}');
  fi

  if [[ -z $lastname ]]; then
    lastname=`dscl . -read /Users/$(whoami) | grep LastName | sed "s/LastName: //"`
  fi
  if [[ -z $firstname ]]; then
    firstname=`dscl . -read /Users/$(whoami) | grep FirstName | sed "s/FirstName: //"`
  fi
  email=`dscl . -read /Users/$(whoami)  | grep EMailAddress | sed "s/EMailAddress: //"`

  if [[ ! "$firstname" ]];then
    response='n'
  else
    echo -e "I see that your full name is $COL_YELLOW$firstname $lastname$COL_RESET"
    read -r -p "Is this correct? [Y|n] " response
  fi

  if [[ $response =~ ^(no|n|N) ]];then
    read -r -p "What is your first name? " firstname
    read -r -p "What is your last name? " lastname
  fi
  fullname="$firstname $lastname"

  bot "Great $fullname, "

  if [[ ! $email ]];then
    response='n'
  else
    echo -e "The best I can make out, your email address is $COL_YELLOW$email$COL_RESET"
    read -r -p "Is this correct? [Y|n] " response
  fi

  if [[ $response =~ ^(no|n|N) ]];then
    read -r -p "What is your email? " email
    if [[ ! $email ]];then
      error "you must provide an email to configure .gitconfig"
      exit 1
    fi
  fi


  running "replacing items in .gitconfig with your info ($COL_YELLOW$fullname, $email, $githubuser$COL_RESET)"

  # test if gnu-sed or MacOS sed

  sed -i "s/GITHUBFULLNAME/$firstname $lastname/" ./homedir/.gitconfig > /dev/null 2>&1 | true
  if [[ ${PIPESTATUS[0]} != 0 ]]; then
    echo
    running "looks like you are using MacOS sed rather than gnu-sed, accommodating"
    sed -i '' "s/GITHUBFULLNAME/$firstname $lastname/" ./homedir/.gitconfig;
    sed -i '' 's/GITHUBEMAIL/'$email'/' ./homedir/.gitconfig;
    sed -i '' 's/GITHUBUSER/'$githubuser'/' ./homedir/.gitconfig;
    ok
  else
    echo
    bot "looks like you are already using gnu-sed. woot!"
    sed -i 's/GITHUBEMAIL/'$email'/' ./homedir/.gitconfig;
    sed -i 's/GITHUBUSER/'$githubuser'/' ./homedir/.gitconfig;
  fi
fi


#####
# install homebrew (CLI Packages)
#####

running "checking homebrew install"
brew_bin=$(which brew) 2>&1 > /dev/null
if [[ $? != 0 ]]; then
  action "installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    if [[ $? != 0 ]]; then
      error "unable to install homebrew, script $0 abort!"
      exit 2
  fi
else
  ok
  # Make sure we’re using the latest Homebrew
  running "updating homebrew"
  brew update
  ok
  # bot "before installing brew packages, we can upgrade any outdated packages."
  # read -r -p "run brew upgrade? [y|N] " response
  # if [[ $response =~ ^(y|yes|Y) ]];then
  #     # Upgrade any already-installed formulae
  #     action "upgrade brew packages..."
  #     brew upgrade
  #     ok "brews updated..."
  # else
  #     ok "skipped brew package upgrades.";
  # fi
fi

#####
# install brew cask (UI Packages)
#####
running "checking brew-cask install"
output=$(brew tap | grep cask)
if [[ $? != 0 ]]; then
  action "installing brew-cask"
  require_brew caskroom/cask/brew-cask
fi
brew tap caskroom/versions > /dev/null 2>&1
ok

# skip those GUI clients, git command-line all the way
require_brew git
# need fontconfig to install/build fonts
require_brew fontconfig
# update zsh to latest
require_brew zsh
# update ruby to latest
# use versions of packages installed with homebrew
RUBY_CONFIGURE_OPTS="--with-openssl-dir=`brew --prefix openssl` --with-readline-dir=`brew --prefix readline` --with-libyaml-dir=`brew --prefix libyaml`"
require_brew ruby
# set zsh as the user login shell
CURRENTSHELL=$(dscl . -read /Users/$USER UserShell | awk '{print $2}')
if [[ "$CURRENTSHELL" != "/usr/local/bin/zsh" ]]; then
  bot "setting newer homebrew zsh (/usr/local/bin/zsh) as your shell (password required)"
  # sudo bash -c 'echo "/usr/local/bin/zsh" >> /etc/shells'
  # chsh -s /usr/local/bin/zsh
  sudo dscl . -change /Users/$USER UserShell $SHELL /usr/local/bin/zsh > /dev/null 2>&1
  ok
fi

if [[ ! -d "./oh-my-zsh/custom/themes/powerlevel9k" ]]; then
  git clone https://github.com/bhilburn/powerlevel9k.git oh-my-zsh/custom/themes/powerlevel9k
fi

bot "creating symlinks for project dotfiles..."
pushd homedir > /dev/null 2>&1
now=$(date +"%Y.%m.%d.%H.%M.%S")

for file in .*; do
  if [[ $file == "." || $file == ".." ]]; then
    continue
  fi
  running "~/$file"
  # if the file exists:
  if [[ -e ~/$file ]]; then
      mkdir -p ~/.dotfiles_backup/$now
      mv ~/$file ~/.dotfiles_backup/$now/$file
      echo "backup saved as ~/.dotfiles_backup/$now/$file"
  fi
  # symlink might still exist
  unlink ~/$file > /dev/null 2>&1
  # create the link
  ln -s ~/.dotfiles/homedir/$file ~/$file
  echo -en '\tlinked';ok
done

popd > /dev/null 2>&1


bot "Installing vim plugins"
# cmake is required to compile vim bundle YouCompleteMe
# require_brew cmake
vim +PluginInstall +qall > /dev/null 2>&1

bot "installing fonts"
require_cask font-hack-nerd-font
require_cask font-fira-code
ok

if [[ -d "/Library/Ruby/Gems/2.0.0" ]]; then
  running "Fixing Ruby Gems Directory Permissions"
  sudo chown -R $(whoami) /Library/Ruby/Gems/2.0.0
  ok
fi

# node version manager
require_brew nvm

# nvm
require_nvm stable

# always pin versions (no surprises, consistent dev/build machines)
npm config set save-exact true

# set taobao mirrors
npm set registry https://registry.npm.taobao.org
npm set disturl https://npm.taobao.org/dist

npm set sass_binary_site https://npm.taobao.org/mirrors/node-sass
npm set electron_mirror https://npm.taobao.org/mirrors/electron
npm set puppeteer_download_host https://npm.taobao.org/mirrors
npm set chromedriver_cdnurl https://npm.taobao.org/mirrors/chromedriver
npm set operadriver_cdnurl https://npm.taobao.org/mirrors/operadriver
npm set phantomjs_cdnurl https://npm.taobao.org/mirrors/phantomjs
npm set selenium_cdnurl https://npm.taobao.org/mirrors/selenium
npm set node_inspector_cdnurl https://npm.taobao.org/mirrors/node-inspector

#####################################
# Now we can switch to node.js mode
# for better maintainability and
# easier configuration via
# JSON files and inquirer prompts
#####################################

bot "installing npm tools needed to run this project..."
npm install
ok

bot "installing packages from config.js..."
node index.js
ok

running "cleanup homebrew"
brew cleanup > /dev/null 2>&1
ok

###############################################################################
bot "Configuring General System UI/UX..."
###############################################################################
# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
running "closing any system preferences to prevent issues with automated changes"
osascript -e 'tell application "System Preferences" to quit'
ok

##############################################################################
# Security                                                                   #
##############################################################################
# Based on:
# https://github.com/drduh/macOS-Security-and-Privacy-Guide
# https://benchmarks.cisecurity.org/tools2/osx/CIS_Apple_OSX_10.12_Benchmark_v1.0.0.pdf

# Enable firewall. Possible values:
#   0 = off
#   1 = on for specific sevices
#   2 = on for essential services
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1

# Enable firewall stealth mode (no response to ICMP / ping requests)
# Source: https://support.apple.com/kb/PH18642
#sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1
sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1

# Enable firewall logging
#sudo defaults write /Library/Preferences/com.apple.alf loggingenabled -int 1

# Do not automatically allow signed software to receive incoming connections
#sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -bool false

# Log firewall events for 90 days
#sudo perl -p -i -e 's/rotate=seq compress file_max=5M all_max=50M/rotate=utc compress file_max=5M ttl=90/g' "/etc/asl.conf"
#sudo perl -p -i -e 's/appfirewall.log file_max=5M all_max=50M/appfirewall.log rotate=utc compress file_max=5M ttl=90/g' "/etc/asl.conf"

# Reload the firewall
# (uncomment if above is not commented out)
#launchctl unload /System/Library/LaunchAgents/com.apple.alf.useragent.plist
#sudo launchctl unload /System/Library/LaunchDaemons/com.apple.alf.agent.plist
#sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist
#launchctl load /System/Library/LaunchAgents/com.apple.alf.useragent.plist

# Disable IR remote control
#sudo defaults write /Library/Preferences/com.apple.driver.AppleIRController DeviceEnabled -bool false

# Turn Bluetooth off completely
#sudo defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0
#sudo launchctl unload /System/Library/LaunchDaemons/com.apple.blued.plist
#sudo launchctl load /System/Library/LaunchDaemons/com.apple.blued.plist

# Disable wifi captive portal
#sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false

# Disable remote apple events
sudo systemsetup -setremoteappleevents off

# Disable remote login
sudo systemsetup -setremotelogin off

# Disable wake-on modem
sudo systemsetup -setwakeonmodem off

# Disable wake-on LAN
sudo systemsetup -setwakeonnetworkaccess off

# Disable file-sharing via AFP or SMB
# sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.AppleFileServer.plist
# sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist

# Display login window as name and password
#sudo defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool true

# Do not show password hints
#sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0

# Disable guest account login
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

# Automatically lock the login keychain for inactivity after 6 hours
#security set-keychain-settings -t 21600 -l ~/Library/Keychains/login.keychain

# Destroy FileVault key when going into standby mode, forcing a re-auth.
# Source: https://web.archive.org/web/20160114141929/http://training.apple.com/pdf/WP_FileVault2.pdf
#sudo pmset destroyfvkeyonstandby 1

# Disable Bonjour multicast advertisements
#sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true

# Disable the crash reporter
#defaults write com.apple.CrashReporter DialogType -string "none"

# Disable diagnostic reports
#sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist

# Log authentication events for 90 days
#sudo perl -p -i -e 's/rotate=seq file_max=5M all_max=20M/rotate=utc file_max=5M ttl=90/g' "/etc/asl/com.apple.authd"

# Log installation events for a year
#sudo perl -p -i -e 's/format=bsd/format=bsd mode=0640 rotate=utc compress file_max=5M ttl=365/g' "/etc/asl/com.apple.install"

# Increase the retention time for system.log and secure.log
#sudo perl -p -i -e 's/\/var\/log\/wtmp.*$/\/var\/log\/wtmp   \t\t\t640\ \ 31\    *\t\@hh24\ \J/g' "/etc/newsyslog.conf"

# Keep a log of kernel events for 30 days
#sudo perl -p -i -e 's|flags:lo,aa|flags:lo,aa,ad,fd,fm,-all,^-fa,^-fc,^-cl|g' /private/etc/security/audit_control
#sudo perl -p -i -e 's|filesz:2M|filesz:10M|g' /private/etc/security/audit_control
#sudo perl -p -i -e 's|expire-after:10M|expire-after: 30d |g' /private/etc/security/audit_control

# Disable the “Are you sure you want to open this application?” dialog
#defaults write com.apple.LaunchServices LSQuarantine -bool false

################################################
bot "Standard System Changes"
################################################

running "allow 'locate' command"
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.locate.plist > /dev/null 2>&1;ok

running "Disable the sound effects on boot"
sudo nvram SystemAudioVolume=" ";ok

running "Menu bar: disable transparency"
defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool false;ok

running "Menu bar: hide the Time Machine, Volume, User, and Bluetooth icons"
for domain in ~/Library/Preferences/ByHost/com.apple.systemuiserver.*; do
  defaults write "${domain}" dontAutoLoad -array \
    "/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
    "/System/Library/CoreServices/Menu Extras/Volume.menu" \
    "/System/Library/CoreServices/Menu Extras/User.menu"
done;
defaults write com.apple.systemuiserver menuExtras -array \
  "/System/Library/CoreServices/Menu Extras/Bluetooth.menu" \
  "/System/Library/CoreServices/Menu Extras/AirPort.menu" \
  "/System/Library/CoreServices/Menu Extras/Battery.menu" \
  "/System/Library/CoreServices/Menu Extras/Clock.menu"
ok

running "Set highlight color to green"
defaults write NSGlobalDomain AppleHighlightColor -string "0.764700 0.976500 0.568600";ok

# running "Set sidebar icon size to medium"
# defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2;ok

# running "Always show scrollbars"
# defaults write NSGlobalDomain AppleShowScrollBars -string "Always";ok
# Possible values: `WhenScrolling`, `Automatic` and `Always`

running "Increase window resize speed for Cocoa applications"
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001;ok

running "Expand save panel by default"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true;ok

running "Expand print panel by default"
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true;ok

running "Save to disk (not to iCloud) by default"
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false;ok

running "Automatically quit printer app once the print jobs complete"
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true;ok

running "Disable the “Are you sure you want to open this application?” dialog"
defaults write com.apple.LaunchServices LSQuarantine -bool false;ok

running "Remove duplicates in the “Open With” menu (also see 'lscleanup' alias)"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user;ok

running "Display ASCII control characters using caret notation in standard text views"
# Try e.g. `cd /tmp; unidecode "\x{0000}" > cc.txt; open -e cc.txt`
defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true;ok

running "Disable automatic termination of inactive apps"
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true;ok

running "Disable the crash reporter"
defaults write com.apple.CrashReporter DialogType -string "none";ok

running "Set Help Viewer windows to non-floating mode"
defaults write com.apple.helpviewer DevMode -bool true;ok

running "Reveal IP, hostname, OS, etc. when clicking clock in login window"
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName;ok

running "Restart automatically if the computer freezes"
sudo systemsetup -setrestartfreeze on;ok

#running "Never go into computer sleep mode"
#sudo systemsetup -setcomputersleep Off > /dev/null;ok

#running "Check for software updates daily, not just once per week"
#defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1;ok

# running "Disable Notification Center and remove the menu bar icon"
# launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist > /dev/null 2>&1;ok

running "Disable smart quotes as they’re annoying when typing code"
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false;ok

running "Disable smart dashes as they’re annoying when typing code"
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false;ok

###############################################################################
bot "Finder Configs"
###############################################################################
running "Keep folders on top when sorting by name (Sierra only)"
defaults write com.apple.finder _FXSortFoldersFirst -bool true

running "Allow quitting via ⌘ + Q; doing so will also hide desktop icons"
defaults write com.apple.finder QuitMenuItem -bool true;ok

running "Disable window animations and Get Info animations"
defaults write com.apple.finder DisableAllAnimations -bool true;ok

running "Set Desktop as the default location for new Finder windows"
# For other paths, use 'PfLo' and 'file:///full/path/here/'
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/";ok

running "Show hidden files by default"
defaults write com.apple.finder AppleShowAllFiles -bool true;ok

running "Show all filename extensions"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true;ok

running "Show status bar"
defaults write com.apple.finder ShowStatusBar -bool true;ok

running "Show path bar"
defaults write com.apple.finder ShowPathbar -bool true;ok

running "Allow text selection in Quick Look"
defaults write com.apple.finder QLEnableTextSelection -bool true;ok

running "Display full POSIX path as Finder window title"
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true;ok

running "When performing a search, search the current folder by default"
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf";ok

running "Disable the warning when changing a file extension"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false;ok

running "Enable spring loading for directories"
defaults write NSGlobalDomain com.apple.springing.enabled -bool true;ok

running "Remove the spring loading delay for directories"
defaults write NSGlobalDomain com.apple.springing.delay -float 0;ok

running "Avoid creating .DS_Store files on network volumes"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true;ok

running "Disable disk image verification"
defaults write com.apple.frameworks.diskimages skip-verify -bool true
defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true;ok

running "Automatically open a new Finder window when a volume is mounted"
defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true;ok

running "Use list view in all Finder windows by default"
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv";ok

running "Disable the warning before emptying the Trash"
defaults write com.apple.finder WarnOnEmptyTrash -bool false;ok

running "Empty Trash securely by default"
defaults write com.apple.finder EmptyTrashSecurely -bool true;ok

running "Enable AirDrop over Ethernet and on unsupported Macs running Lion"
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true;ok

running "Show the ~/Library folder"
chflags nohidden ~/Library;ok


running "Expand the following File Info panes: “General”, “Open with”, and “Sharing & Permissions”"
defaults write com.apple.finder FXInfoPanesExpanded -dict \
  General -bool true \
  OpenWith -bool true \
  Privileges -bool true;ok

###############################################################################
bot "Dock & Dashboard"
###############################################################################

running "Enable highlight hover effect for the grid view of a stack (Dock)"
defaults write com.apple.dock mouse-over-hilite-stack -bool true;ok

running "Set the icon size of Dock items to 36 pixels"
defaults write com.apple.dock tilesize -int 36;ok

running "Change minimize/maximize window effect to scale"
defaults write com.apple.dock mineffect -string "scale";ok

running "Minimize windows into their application’s icon"
defaults write com.apple.dock minimize-to-application -bool true;ok

running "Enable spring loading for all Dock items"
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true;ok

running "Show indicator lights for open applications in the Dock"
defaults write com.apple.dock show-process-indicators -bool true;ok

running "Don’t animate opening applications from the Dock"
defaults write com.apple.dock launchanim -bool false;ok

running "Speed up Mission Control animations"
defaults write com.apple.dock expose-animation-duration -float 0.1;ok

running "Don’t group windows by application in Mission Control"
# (i.e. use the old Exposé behavior instead)
defaults write com.apple.dock expose-group-by-app -bool false;ok

running "Disable Dashboard"
defaults write com.apple.dashboard mcx-disabled -bool true;ok

running "Don’t show Dashboard as a Space"
defaults write com.apple.dock dashboard-in-overlay -bool true;ok

running "Don’t automatically rearrange Spaces based on most recent use"
defaults write com.apple.dock mru-spaces -bool false;ok

running "Remove the auto-hiding Dock delay"
defaults write com.apple.dock autohide-delay -float 0;ok
running "Remove the animation when hiding/showing the Dock"
defaults write com.apple.dock autohide-time-modifier -float 0;ok

running "Automatically hide and show the Dock"
defaults write com.apple.dock autohide -bool true;ok

running "Make Dock icons of hidden applications translucent"
defaults write com.apple.dock showhidden -bool true;ok

running "Make Dock more transparent"
defaults write com.apple.dock hide-mirror -bool true;ok

###############################################################################
bot "Configuring Safari & WebKit"
###############################################################################

running "Set Safari’s home page to ‘about:blank’ for faster loading"
defaults write com.apple.Safari HomePage -string "about:blank";ok

running "Prevent Safari from opening ‘safe’ files automatically after downloading"
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false;ok

running "Allow hitting the Backspace key to go to the previous page in history"
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled -bool true;ok

running "Hide Safari’s bookmarks bar by default"
defaults write com.apple.Safari ShowFavoritesBar -bool false;ok

running "Hide Safari’s sidebar in Top Sites"
defaults write com.apple.Safari ShowSidebarInTopSites -bool false;ok

running "Disable Safari’s thumbnail cache for History and Top Sites"
defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2;ok

running "Enable Safari’s debug menu"
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true;ok

running "Make Safari’s search banners default to Contains instead of Starts With"
defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false;ok

running "Remove useless icons from Safari’s bookmarks bar"
defaults write com.apple.Safari ProxiesInBookmarksBar "()";ok

running "Enable the Develop menu and the Web Inspector in Safari"
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true;ok

running "Add a context menu item for showing the Web Inspector in web views"
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true;ok

###############################################################################
bot "Terminal & iTerm2"
###############################################################################

# running "Only use UTF-8 in Terminal.app"
# defaults write com.apple.terminal StringEncodings -array 4;ok
#
# running "Use a modified version of the Solarized Dark theme by default in Terminal.app"
# TERM_PROFILE='Solarized Dark xterm-256color';
# CURRENT_PROFILE="$(defaults read com.apple.terminal 'Default Window Settings')";
# if [ "${CURRENT_PROFILE}" != "${TERM_PROFILE}" ]; then
# 	open "./configs/${TERM_PROFILE}.terminal";
# 	sleep 1; # Wait a bit to make sure the theme is loaded
# 	defaults write com.apple.terminal 'Default Window Settings' -string "${TERM_PROFILE}";
# 	defaults write com.apple.terminal 'Startup Window Settings' -string "${TERM_PROFILE}";
# fi;

#running "Enable “focus follows mouse” for Terminal.app and all X11 apps"
# i.e. hover over a window and start `typing in it without clicking first
defaults write com.apple.terminal FocusFollowsMouse -bool true

running "Don’t display the annoying prompt when quitting iTerm"
defaults write com.googlecode.iterm2 PromptOnQuit -bool false;ok
running "hide tab title bars"
defaults write com.googlecode.iterm2 HideTab -bool true;ok
running "set system-wide hotkey to show/hide iterm with ^\`"
defaults write com.googlecode.iterm2 Hotkey -bool true;ok
running "hide pane titles in split panes"
defaults write com.googlecode.iterm2 ShowPaneTitles -bool false;ok
running "animate split-terminal dimming"
defaults write com.googlecode.iterm2 AnimateDimming -bool true;ok
defaults write com.googlecode.iterm2 HotkeyChar -int 96;
defaults write com.googlecode.iterm2 HotkeyCode -int 50;
defaults write com.googlecode.iterm2 FocusFollowsMouse -int 1;
defaults write com.googlecode.iterm2 HotkeyModifiers -int 262401;
running "Make iTerm2 load new tabs in the same directory"
/usr/libexec/PlistBuddy -c "set \"New Bookmarks\":0:\"Custom Directory\" Recycle" ~/Library/Preferences/com.googlecode.iterm2.plist
running "setting fonts"
defaults write com.googlecode.iterm2 "Normal Font" -string "HackNerdFontComplete-Regular 12";
defaults write com.googlecode.iterm2 "Non Ascii Font" -string "HackNerdFontComplete-Regular 12";
ok
running "reading iterm settings"
defaults read -app iTerm > /dev/null 2>&1;
ok

###############################################################################
bot "Time Machine"
###############################################################################

running "Prevent Time Machine from prompting to use new hard drives as backup volume"
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true;ok

running "Disable local Time Machine backups"
hash tmutil &> /dev/null && sudo tmutil disablelocal;ok

###############################################################################
bot "Activity Monitor"
###############################################################################

running "Show the main window when launching Activity Monitor"
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true;ok

running "Visualize CPU usage in the Activity Monitor Dock icon"
defaults write com.apple.ActivityMonitor IconType -int 5;ok

running "Show all processes in Activity Monitor"
defaults write com.apple.ActivityMonitor ShowCategory -int 0;ok

running "Sort Activity Monitor results by CPU usage"
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0;ok

###############################################################################
bot "Address Book, Dashboard, iCal, TextEdit, and Disk Utility"
###############################################################################

#running "Enable the debug menu in Address Book"
#defaults write com.apple.addressbook ABShowDebugMenu -bool true;ok

running "Enable Dashboard dev mode (allows keeping widgets on the desktop)"
defaults write com.apple.dashboard devmode -bool true;ok

running "Use plain text mode for new TextEdit documents"
defaults write com.apple.TextEdit RichText -int 0;ok
running "Open and save files as UTF-8 in TextEdit"
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4;ok

#running "Enable the debug menu in Disk Utility"
#defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
#defaults write com.apple.DiskUtility advanced-image-options -bool true;ok

###############################################################################
# Kill affected applications                                                  #
###############################################################################
bot "OK. Note that some of these changes require a logout/restart to take effect. Killing affected applications (so they can reboot)...."
for app in "Activity Monitor" "Address Book" "Calendar" "Contacts" "cfprefsd" \
  "Dock" "Finder" "Mail" "Messages" "Safari" "SizeUp" "SystemUIServer" \
  "iCal" "Terminal"; do
  killall "${app}" > /dev/null 2>&1
done

bot "Woot! All done. Kill this terminal and launch iTerm"
