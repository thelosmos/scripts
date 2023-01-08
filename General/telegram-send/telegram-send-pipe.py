#This script is independet of lib or python version (tested on python 2.7 and 3.5)

import telegram
import sys

#token that can be generated talking with @BotFather on telegram
my_token = ''
chat_id = ''

def send(msg, chat_id, token=my_token):
	"""
	Send a mensage to a telegram user specified on chatId
	chat_id must be a number!
	"""
	bot = telegram.Bot(token=token)
	bot.sendMessage(chat_id=chat_id, text=msg)

msg = sys.stdin.read()
send(msg, chat_id, my_token)
