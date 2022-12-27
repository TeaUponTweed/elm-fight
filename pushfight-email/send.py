#!/usr/bin/env python3

import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from contextlib import contextmanager
from typing import Iterator
import fire

_FROM_ADDRESS = "derivativeworks.co@gmail.com"
to_address = "teaupontweed@gmail.com"

def create_message(subject: str, receiver: str, contents_html: str, sender: str = _FROM_ADDRESS) -> MIMEMultipart:
    # Create message container - the correct MIME type is multipart/alternative.
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = sender
    msg['To'] = receiver

    # Record the MIME type - text/html.
    # TODO can add style https://developers.google.com/gmail/design/css#example
    part1 = MIMEText(contents_html, 'html')

    # Attach parts into message container
    msg.attach(part1)

    return msg


# Sending the email
@contextmanager
def _get_server() -> Iterator[smtplib.SMTP]:
    # Credentials
    username = os.environ['GMAIL_EMAIL']  
    password = os.environ['GMAIL_SMTP_PW']
    server = smtplib.SMTP('smtp.gmail.com', 587) 
    server.ehlo()
    server.starttls()
    server.login(username,password)  
    try:
        yield server
    finally:
        server.quit()


def arbitrary(to: str, subject: str, msg: str):
    msg = create_message(receiver=to, subject=subject, contents_html=msg)
    with _get_server() as server:
        server.sendmail(_FROM_ADDRESS, to, msg.as_string())

def turn_notification(to, gameID):
    subject = f"It's the next turn for game {gameID}"
    msg = f'<p>Go to https://www.masonuvagun.xyz?gameID={gameID} to make your move</p>'
    msg = create_message(receiver=to, subject=subject, contents_html=msg)
    with _get_server() as server:
        server.sendmail(_FROM_ADDRESS, to, msg.as_string())


if __name__ == '__main__':
    fire.Fire()
