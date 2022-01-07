#!/bin/bash

function check_github_release_latest_version {
    local account=$1
    local project=$2
    local latest_release=$(curl -L -s -H 'Accept: application/json' https://github.com/$account/$project/releases/latest)
    local latest_version=$(echo $latest_release | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
    echo $latest_version
}

function zip_download_tar_install_clean {
    local download_url=$1
    local opt_func=$2

    echo "start to downlaod file from $download_url"
    wget $download_url -o /dev/null

    local filename=${download_url##*/}
    $opt_func $filename

    echo "remove download file"
    rm -f $filename
}

function install_clash {
    local filename=$1

    if ! [[ $clash_subscribe_url =~ ^http.* ]]; then
        echo "Invaild subscribe url"
        return
    fi

    if wget $clash_subscribe_url -O config.yaml &>/dev/null; then
        echo "Download clash config file successfully."
    else
        echo "Download config file from subscribe failed."
        return
    fi

    if [ -d "/etc/clash" ]; then
        echo "Directory /opt/clash exists. skip clash."
        return
    fi

    echo "Make clash directory: /etc/clash"
    sudo mkdir /etc/clash
    sudo chmod -R 777 /etc/clash
    cp config.yaml /etc/clash/

    gunzip -kc $filename >/usr/local/bin/clash
    sudo chmod +x /usr/local/bin/clash
    sudo cp $project_dir/clash.service /etc/systemd/system/clash.service

    sudo systemctl enable clash
    sudo systemctl start clash

    export HTTP_PROXY="127.0.0.1:7890"
    export HTTPS_PROXY="127.0.0.1:7890"

    echo "Checking proxy status..."
    if curl "https://www.google.com.hk/" --connect-timeout 3 &>/dev/null; then
        proxy_flag=1
    else
        echo "Clash config failed."
        export HTTP_PROXY=
        export HTTPS_PROXY=
    fi
}

function install_dbeaver() {
    local filename=$1
    sudo dkpg -i $filename
}

echo "Welcome! Let's start setting up your system. It could take more than 10 minutes, be patient"

workdir=ubuntu_setup_tempdir
project_dir=$(pwd)

proxy_flag=0

echo "What name do you want to use in GIT user.name?"
echo "For example, mine will be \"harumonia\""
read git_config_user_name

echo "What email do you want to use in GIT user.email?"
echo "For example, mine will be \"harumonia@gmail.com\""
read git_config_user_email

# echo "What is your github username?"
# echo "For example, mine will be \"zxjlm\""
# read username

echo "Please input the clash subscribe url: "
echo "you can skip it, but it may cause some software which need proxy failed to install."
read clash_subscribe_url

cd ~ && sudo apt-get update

echo "Creating tmpfile directory"
mkdir -p ~/$workdir
cd ~/$workdir

echo 'Installing curl'
sudo apt-get install curl -y

# echo 'Installing neofetch'
# sudo apt-get install neofetch -y

echo 'Installing tool to handle clipboard via CLI'
sudo apt-get install xclip -y

echo 'Installing latest git'
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-get update && sudo apt-get install git -y

echo 'Installing python3-pip'
sudo apt-get install python3-pip -y

# echo 'Installing getgist to download dot files from gist'
# sudo pip3 install getgist
# export GETGIST_USER=$username

echo "Setting up your git global user name and email"
git config --global user.name "$git_config_user_name"
git config --global user.email "$git_config_user_email"

# echo 'Cloning your .gitconfig from gist'
# getmy .gitconfig

echo 'Generating a SSH Key'
ssh-keygen -t rsa -b 4096 -C $git_config_user_email
ssh-add ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub | xclip -selection clipboard

echo "Installing Clash"
clash_latest_version=$(check_github_release_latest_version Dreamacro clash)
clash_download_url = "https://github.com/Dreamacro/clash/releases/download/$clash_latest_version/clash-linux-amd64-$clash_latest_version.gz"
zip_download_tar_install_clean $clash_download_url install_clash

echo 'Installing ZSH'
sudo apt-get install zsh -y
sh -c "$(wget https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
chsh -s $(which zsh)

# echo 'Cloning your .zshrc from gist'
# getmy .zshrc

# echo 'Indexing snap to ZSH'
# sudo chmod 777 /etc/zsh/zprofile
# echo "emulate sh -c 'source /etc/profile.d/apps-bin-path.sh'" >>/etc/zsh/zprofile

# echo 'Installing Spaceship ZSH Theme'
# git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
# ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
# source ~/.zshrc

# echo 'Installing FiraCode'
# sudo apt-get install fonts-firacode -y

echo 'Installing NVM'
sh -c "$(curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash)"

export NVM_DIR="$HOME/.nvm" && (
    git clone https://github.com/creationix/nvm.git "$NVM_DIR"
    cd "$NVM_DIR"
    git checkout $(git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1))
) && \. "$NVM_DIR/nvm.sh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

source ~/.zshrc
# clear

echo 'Installing NodeJS LTS'
nvm --version
nvm install --lts
nvm current

echo 'Installing Yarn'
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update && sudo apt-get install --no-install-recommends yarn
echo '"--emoji" true' >>~/.yarnrc

# echo 'Installing Typescript, AdonisJS CLI and Lerna'
# yarn global add typescript @adonisjs/cli lerna
# clear

echo 'Installing VSCode'
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt-get install apt-transport-https -y
sudo apt-get update && sudo apt-get install code -y

# echo 'Installing Code Settings Sync'
# code --install-extension Shan.code-settings-sync
# sudo apt-get install gnome-keyring -y
# cls

# echo 'Installing Vivaldi'
# wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | sudo apt-key add -
# sudo add-apt-repository 'deb https://repo.vivaldi.com/archive/deb/ stable main' -y
# sudo apt update && sudo apt install vivaldi-stable

# echo 'Launching Vivaldi on Github so you can paste your keys'
# vivaldi https://github.com/settings/keys </dev/null >/dev/null 2>&1 &
# disown

echo "Installing Clash"
clash_latest_version=$(check_github_release_latest_version Dreamacro clash)
clash_download_url = "https://github.com/Dreamacro/clash/releases/download/$clash_latest_version/clash-linux-amd64-$clash_latest_version.gz"
zip_download_tar_install_clean $clash_download_url install_clash

echo "Installing Clash"
dbeaver_latest_version=$(check_github_release_latest_version dbeaver dbeaver)
dbeaver_download_url = "https://github.com/dbeaver/dbeaver/releases/download/$dbeaver_latest_version/dbeaver-ce_$dbeaver_latest_version_amd64.deb"
zip_download_tar_install_clean $clash_download_url install_dbeaver

# ------------------------------------------------- docker divide ------------------------------------

echo 'Installing Docker'
sudo apt-get install ca-certificates gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io

sudo groupadd docker
sudo usermod -aG docker $USER
sudo chmod 777 /var/run/docker.sock

echo 'Installing docker-compose'
sudo curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

# echo 'Installing Insomnia Core and Omni Theme'
# echo "deb https://dl.bintray.com/getinsomnia/Insomnia /" |
#     sudo tee -a /etc/apt/sources.list.d/insomnia.list
# wget --quiet -O - https://insomnia.rest/keys/debian-public.key.asc |
#     sudo apt-key add -
# sudo apt-get update && sudo apt-get install insomnia -y
# mkdir ~/.config/Insomnia/plugins && cd ~/.config/Insomnia/plugins
# git clone https://github.com/Rocketseat/insomnia-omni.git omni-theme && cd ~

# echo 'Installing Lotion'
# sudo git clone https://github.com/puneetsl/lotion.git /usr/local/lotion
# cd /usr/local/lotion && sudo ./install.sh

echo 'Updating and Cleaning Unnecessary Packages'
sudo -- sh -c 'apt-get update; apt-get upgrade -y; apt-get full-upgrade -y; apt-get autoremove -y; apt-get autoclean -y'
# clear

echo 'Installing mongodb container'
docker run --name mongodb -p 27017:27017 -d -t mongo

echo 'Installing redis container'
docker run --name redis_skylab -p 6379:6379 -d -t redis:alpine
clear

# echo 'Bumping the max file watchers'
# echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

# echo 'Generating GPG key'
# gpg --full-generate-key
# gpg --list-secret-keys --keyid-format LONG

# echo 'Paste the GPG key ID to export and add to your global .gitconfig'
# read gpg_key_id
# git config --global user.signingkey $gpg_key_id
# gpg --armor --export $gpg_key_id

echo 'All setup, enjoy!'
