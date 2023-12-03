import { Stack, Section, Button, Box, Input, Modal, Tooltip, Icon } from '../../components';
import { Component, RefObject, createRef, SFC, InfernoNode } from 'inferno';
import { NtMessage, NtMessenger } from './types';
import { BooleanLike } from 'common/react';
import { useBackend } from '../../backend';
import { decodeHtmlEntities } from 'common/string';

type ChatScreenProps = {
  canReply: BooleanLike;
  chatRef?: string;
  messages: NtMessage[];
  recipient: NtMessenger;
  selectedPhoto: string | null;
  sendingVirus: BooleanLike;
  unreads: number;
};

type ChatScreenState = {
  canSend: boolean;
  message: string;
  previewingPhoto?: string;
};

const READ_UNREADS_TIME_MS = 1000;
const SEND_COOLDOWN_MS = 1000;

export class ChatScreen extends Component<ChatScreenProps, ChatScreenState> {
  readUnreadsTimeout: NodeJS.Timeout | null = null;
  scrollRef: RefObject<HTMLDivElement>;

  state: ChatScreenState = {
    message: '',
    canSend: true,
  };

  constructor(props: ChatScreenProps) {
    super(props);

    this.scrollRef = createRef();

    this.scrollToBottom = this.scrollToBottom.bind(this);
    this.handleMessageInput = this.handleMessageInput.bind(this);
    this.handleSelectPicture = this.handleSelectPicture.bind(this);
    this.handleSendMessage = this.handleSendMessage.bind(this);
    this.trySetReadTimeout = this.trySetReadTimeout.bind(this);
    this.tryClearReadTimeout = this.tryClearReadTimeout.bind(this);
    this.clearUnreads = this.clearUnreads.bind(this);
  }

  componentDidMount() {
    this.scrollToBottom();
    this.trySetReadTimeout();
  }

  componentDidUpdate(
    prevProps: ChatScreenProps,
    _prevState: ChatScreenState,
    _snapshot: any
  ) {
    if (prevProps.messages.length !== this.props.messages.length) {
      this.scrollToBottom();
      this.trySetReadTimeout();
    }
  }

  componentWillUnmount() {
    if (!this.props.chatRef) {
      return;
    }

    const { act } = useBackend();

    this.tryClearReadTimeout();

    act('PDA_saveMessageDraft', {
      ref: this.props.chatRef,
      message: this.state.message,
    });
  }

  trySetReadTimeout() {
    if (!this.props.chatRef) {
      return;
    }
    const unreadMessages = this.props.unreads;

    this.tryClearReadTimeout();

    if (unreadMessages > 0) {
      this.readUnreadsTimeout = setTimeout(() => {
        this.clearUnreads();
        this.readUnreadsTimeout = null;
      }, READ_UNREADS_TIME_MS);
    }
  }

  tryClearReadTimeout() {
    if (this.readUnreadsTimeout) {
      clearTimeout(this.readUnreadsTimeout);
      this.readUnreadsTimeout = null;
    }
  }

  clearUnreads() {
    const { act } = useBackend();

    act('PDA_clearUnreads', { ref: this.props.chatRef });
  }

  scrollToBottom() {
    const scroll = this.scrollRef.current;
    if (scroll !== null) {
      scroll.scrollTop = scroll.scrollHeight;
    }
  }

  handleSelectPicture() {
    const { isSilicon } = this.props;
    const { act } = useBackend();
    if (isSilicon) {
      act('PDA_siliconSelectPhoto');
    } else {
      act('PDA_uploadPhoto');
    }
  }

  handleSendMessage() {
    if (this.state.message === '') {
      return;
    }

    const { act } = useBackend();
    const { chatRef, recipient } = this.props;

    let ref = chatRef ? chatRef : recipient.ref;

    act('PDA_sendMessage', {
      ref: ref,
      message: this.state.message,
    });

    this.setState({ message: '', canSend: false });
    setTimeout(() => this.setState({ canSend: true }), SEND_COOLDOWN_MS);
  }

  handleMessageInput(_: any, val: string) {
    this.setState({ message: val });
  }

  render() {
    const { act } = useBackend();
    const {
      canReply,
      messages,
      recipient,
      chatRef,
      selectedPhoto,
      sendingVirus,
      unreads,
    } = this.props;
    const { message, canSend, previewingPhoto } = this.state;

    let filteredMessages: JSX.Element[] = [];

    for (let index = 0; index < messages.length; index++) {
      const message = messages[index];
      const isSwitch = !(
        index === 0 || messages[index - 1].outgoing === message.outgoing
      );

      if (index === messages.length - unreads) {
        filteredMessages.push(
          <ChatDivider mt={isSwitch ? 3 : 1} text="Unread Messages" />
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
                ? () => this.setState({ previewingPhoto: message.photo_path! })
                : undefined
            }
          />
        </Stack.Item>
      );
    }

    let sendingBar: JSX.Element;

    if (!canReply) {
      sendingBar = (
        <Section fill>
          <Box width="100%" italic color="gray" ml={1}>
            You cannot reply to this user.
          </Box>
        </Section>
      );
    } else {
      const attachmentButton = sendingVirus ? (
        <Button
          tooltip="ERROR: File signature is unverified. Please contact an NT support intern."
          icon="triangle-exclamation"
          color="red"
        />
      ) : (
        <Button
          tooltip={selectedPhoto ? 'View attachment' : 'Scan photo'}
          icon={selectedPhoto ? 'image' : 'upload'}
          onClick={this.handleSelectPicture}
        />
      );

      const buttons = canReply ? (
        <>
          <Stack.Item>{attachmentButton}</Stack.Item>
          <Stack.Item>
            <Button
              tooltip="Send"
              icon="arrow-right"
              onClick={this.handleSendMessage}
              disabled={!canSend}
            />
          </Stack.Item>
        </>
      ) : (
        ''
      );

      sendingBar = (
        <Section fill>
          <Stack fill align="center">
            <Stack.Item grow={1}>
              <Input
                placeholder={`Send message to ${recipient.name}...`}
                fluid
                autoFocus
                width="100%"
                justify
                id="input"
                value={message}
                maxLength={1024}
                onInput={this.handleMessageInput}
                onEnter={this.handleSendMessage}
              />
            </Stack.Item>
            {buttons}
          </Stack>
        </Section>
      );
    }

    return (
      <Stack vertical fill>
        <Stack.Item>
          <Section>
            <Button
              icon="arrow-left"
              content="Back"
              onClick={() => act('PDA_viewMessages', { ref: null })}
            />
            {chatRef && (
              <>
                <Button
                  icon="box-archive"
                  content="Close chat"
                  onClick={() => act('PDA_closeMessages', { ref: chatRef })}
                />
                <Button.Confirm
                  icon="trash-can"
                  content="Delete chat"
                  onClick={() => act('PDA_clearMessages', { ref: chatRef })}
                />
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
            scrollableRef={this.scrollRef}>
            <Stack vertical className="NtosChatLog">
              {!!(messages.length > 0 && canReply) && (
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

        <Stack.Item>{sendingBar}</Stack.Item>

        {previewingPhoto && (
          <PhotoPreview
            img={previewingPhoto}
            buttons={
              <>
                {previewingPhoto === selectedPhoto && (
                  <Button
                    content="Clear Photo"
                    color="red"
                    icon="xmark"
                    onClick={() => {
                      this.setState({ previewingPhoto: undefined });
                      act('PDA_clearPhoto');
                    }}
                  />
                )}
                <Button
                  content="Back"
                  icon="arrow-left"
                  onClick={() => this.setState({ previewingPhoto: undefined })}
                />
              </>
            }
          />
        )}
      </Stack>
    );
  }
}

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
      {photoPath !== null && (
        <Button
          tooltip="View image"
          className="NtosChatMessage__image"
          color="transparent"
          onClick={onPreviewImage}>
          <Box as="img" src={photoPath} mt={1} />
        </Button>
      )}
    </Box>
  );
};

type PhotoPreviewProps = {
  buttons: InfernoNode;
  img: string;
};

export const PhotoPreview: SFC<PhotoPreviewProps> = (props) => {
  return (
    <Modal className="NtosChatLog__ImagePreview">
      <Section title="Photo Preview" buttons={props.buttons}>
        <Box as="img" src={props.img} />
      </Section>
    </Modal>
  );
};

type ChatDividerProps = {
  mt: number;
  text: string;
};

const ChatDivider: SFC<ChatDividerProps> = (props) => {
  return (
    <Box class="ChatDivider" m={0} mt={props.mt}>
      <div />
      <span>{props.text}</span>
      <div />
    </Box>
  );
};
