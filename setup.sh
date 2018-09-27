if [ -f ~/.zshrc ]; then
	echo "backup up ~/.zshrc"
	mv ~/.zshrc ~/.zshrc.bak
fi

if [ -f ~/.tmux.conf ]; then
	echo "backup up ~/.zshrc"
	mv ~/.tmux.conf ~/.tmux.conf.bak
fi

ln -s ~/.config/.zshrc ~/.zshrc

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
ln -s ~/.config/tmux.conf ~/.tmux.conf
