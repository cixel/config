if [ -f ~/.zshrc ]; then
	echo "backup up ~/.zshrc"
	mv ~/.zshrc ~/.zshrc.bak
fi

if [ -f ~/.tmux.conf]; then
	echo "backup up ~/.zshrc"
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
	mv ~/.tmux.conf ~/.tmux.conf.bak
fi

ln -s .zshrc /.config/.zshrc
ln -s tmux.conf /.config/tmux.conf
