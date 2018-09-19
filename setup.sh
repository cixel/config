if [ -f /Users/ehdens/.zshrc ]; then
	echo "backup up ~/.zshrc"
	mv /Users/ehdens/.zshrc /Users/ehdens/.zshrc.bak
fi

ln -s .zshrc /Users/ehdens/.config/.zshrc
