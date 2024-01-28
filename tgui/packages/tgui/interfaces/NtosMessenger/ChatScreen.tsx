import { BooleanLike } from 'common/react';
import { decodeHtmlEntities } from 'common/string';
import { useEffect, useRef, useState } from 'react';

import { useBackend } from '../../backend';
import {
  Box,
  Button,
  Icon,
  Image,
  Input,
  Modal,
  Section,
  Stack,
  Tooltip,
} from '../../components';
import { NtMessage, NtMessenger } from './types';

type ChatScreenProps = {
  canReply: boolean;
  chatId?: string;
  messages: NtMessage[];
  recipient: NtMessenger;
  selectedPhoto: string | null;
  sendingVirus: boolean;
  unreads: number;
};

const READ_UNREADS_TIME_MS = 1000;
const SEND_COOLDOWN_MS = 1000;

export const ChatScreen = (props: ChatScreenProps) => {
  const { act } = useBackend();
  const {
    canReply,
    messages,
    recipient,
    chatId,
    selectedPhoto,
    sendingVirus,
    unreads,
  } = props;

  const [message, setMessage] = useState('');
  const [canSend, setCanSend] = useState(true);
  const [previewPhoto, setPreviewPhoto] = useState<string | null>(null);

  const scrollRef = useRef<HTMLDivElement>(null);
  const saveDraftRef = useRef(() => {});

  useEffect(() => () => saveDraftRef.current(), []);

  useEffect(() => {
    saveDraftRef.current =
      message === '' || chatId === undefined
        ? () => {}
        : () => {
            act('PDA_saveMessageDraft', {
              ref: chatId,
              message: message,
            });
          };
  }, [message, chatId]);

  useEffect(() => {
    if (unreads === 0) {
      return;
    }

    const scroll = scrollRef.current;
    if (scroll !== null) {
      scroll.scrollTop = scroll.scrollHeight;
    }

    const readUnreadsTimeout = setTimeout(() => {
      act('PDA_clearUnreads', { ref: chatId });
    }, READ_UNREADS_TIME_MS);

    return () => {
      clearTimeout(readUnreadsTimeout);
    };
  }, [unreads, chatId]);

  const filteredMessages: JSX.Element[] = [];

  for (let index = 0; index < messages.length; index++) {
    const message = messages[index];
    const isSwitch = !(
      index !== 0 && messages[index - 1].outgoing !== message.outgoing
    );

    if (index === messages.length - unreads) {
      filteredMessages.push(
        <ChatDivider mt={isSwitch ? 3 : 1} text="Unread Messages" />,
      );
    }

    filteredMessages.push(
      <Stack.Item key={index} mt={isSwitch ? 3 : 1}>
        <ChatMessage
          outgoing={message.outgoing}
          message={message.message}
          everyone={message.everyone}
          photoPath={message.photo_path}
          timestamp={message.timestamp}
          onPreviewImage={
            message.photo_path
              ? () => setPreviewPhoto(message.photo_path!)
              : undefined
          }
        />
      </Stack.Item>,
    );
  }

  const handleSendMessage = () => {
    if (message === '') {
      return;
    }

    let ref = chatId ? chatId : recipient.ref!;

    act('PDA_sendMessage', {
      ref: ref,
      message: message,
    });

    setMessage('');
    setCanSend(false);
    setTimeout(() => setCanSend(true), SEND_COOLDOWN_MS);
  };

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Section>
          <Button
            icon="arrow-left"
            onClick={() => act('PDA_viewMessages', { ref: null })}
          >
            Back
          </Button>
          {chatId && (
            <>
              <Button
                icon="box-archive"
                onClick={() => act('PDA_closeMessages', { ref: chatId })}
              >
                Close chat
              </Button>
              <Button.Confirm
                icon="trash-can"
                onClick={() => act('PDA_clearMessages', { ref: chatId })}
              >
                Delete chat
              </Button.Confirm>
            </>
          )}
        </Section>
      </Stack.Item>

      <Stack.Item grow={1}>
        <Section
          scrollable
          fill
          fitted
          title={`${recipient.name} (${recipient.job})`}
          ref={scrollRef}
        >
          <Stack vertical className="NtosChatLog">
            {messages.length > 0 && canReply && (
              <>
                <Stack.Item textAlign="center" fontSize={1}>
                  This is the beginning of your chat with {recipient.name}.
                </Stack.Item>
                <Stack.Divider />
              </>
            )}
            {filteredMessages}
          </Stack>
        </Section>
      </Stack.Item>

      <Stack.Item>
        {!canReply ? (
          <Section fill>
            <Box width="100%" italic color="gray" ml={1}>
              You cannot reply to this user.
            </Box>
          </Section>
        ) : (
          <Section fill>
            <Stack fill align="center">
              <Stack.Item grow={1}>
                <Input
                  placeholder={`Send message to ${recipient.name}...`}
                  fluid
                  autoFocus
                  width="100%"
                  value={message}
                  maxLength={1024}
                  onInput={(_, value) => setMessage(value)}
                  onEnter={handleSendMessage}
                />
              </Stack.Item>
              <Stack.Item>
                {sendingVirus ? (
                  <Button
                    tooltip="ERROR: File signature is unverified. Please contact an NT support intern."
                    icon="triangle-exclamation"
                    color="red"
                  />
                ) : (
                  <Button
                    tooltip={
                      selectedPhoto ? 'View photo' : 'Scan photo in hand'
                    }
                    icon={selectedPhoto ? 'image' : 'upload'}
                    onClick={
                      selectedPhoto
                        ? () => setPreviewPhoto(selectedPhoto)
                        : () => act('PDA_uploadPhoto')
                    }
                  />
                )}
              </Stack.Item>
              <Stack.Item>
                <Button
                  tooltip="Send"
                  icon="arrow-right"
                  onClick={handleSendMessage}
                  disabled={!canSend}
                />
              </Stack.Item>
            </Stack>
          </Section>
        )}
      </Stack.Item>

      {previewPhoto && (
        <PhotoPreview
          img={previewPhoto}
          buttons={
            <>
              {previewPhoto === selectedPhoto && (
                <Button
                  color="red"
                  icon="xmark"
                  onClick={() => {
                    setPreviewPhoto(null);
                    act('PDA_clearPhoto');
                  }}
                >
                  Clear Photo
                </Button>
              )}
              <Button icon="arrow-left" onClick={() => setPreviewPhoto(null)}>
                Back
              </Button>
            </>
          }
        />
      )}
    </Stack>
  );
};

type ChatMessageProps = {
  outgoing: BooleanLike;
  message: string;
  everyone: BooleanLike;
  timestamp: string;
  photoPath?: string;
  onPreviewImage?: () => void;
};

const ChatMessage = (props: ChatMessageProps) => {
  const { message, everyone, outgoing, photoPath, timestamp, onPreviewImage } =
    props;

  const displayMessage = decodeHtmlEntities(message);

  return (
    <Box className={`NtosChatMessage${outgoing ? '_outgoing' : ''}`}>
      <Box className="NtosChatMessage__content">
        <Box as="span">{displayMessage}</Box>
        <Tooltip content={timestamp} position={outgoing ? 'left' : 'right'}>
          <Icon
            className="NtosChatMessage__timestamp"
            name="clock-o"
            size={0.8}
          />
        </Tooltip>
      </Box>
      {!!everyone && (
        <Box className="NtosChatMessage__everyone">Sent to everyone</Box>
      )}
      {!!photoPath && (
        <Button
          tooltip="View image"
          className="NtosChatMessage__image"
          color="transparent"
          onClick={onPreviewImage}
        >
          <Image src={photoPath} mt={1} />
        </Button>
      )}
    </Box>
  );
};

type PhotoPreviewProps = {
  buttons: JSX.Element;
  img: string;
};

const PhotoPreview = (props: PhotoPreviewProps) => {
  return (
    <Modal className="NtosChatLog__ImagePreview">
      <Section title="Photo Preview" buttons={props.buttons}>
        <Image src={props.img} />
      </Section>
    </Modal>
  );
};

type ChatDividerProps = {
  mt: number;
  text: string;
};

const ChatDivider = (props: ChatDividerProps) => {
  return (
    <Box className="ChatDivider" m={0} mt={props.mt}>
      <div />
      <span>{props.text}</span>
      <div />
    </Box>
  );
};
