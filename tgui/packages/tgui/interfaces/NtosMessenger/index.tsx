import { sortBy } from 'common/collections';
import { BooleanLike } from 'common/react';
import { createSearch } from 'common/string';
import { useState } from 'react';

import { useBackend } from '../../backend';
import {
  Box,
  Button,
  Dimmer,
  Divider,
  Icon,
  Input,
  Section,
  Stack,
  TextArea,
} from '../../components';
import { NtosWindow } from '../../layouts';
import { ChatScreen, PhotoPreview } from './ChatScreen';
import { NtChat, NtMessenger } from './types';

type NtosMessengerData = {
  can_spam: BooleanLike;
  owner: NtMessenger | null;
  saved_chats: Record<string, NtChat>;
  messengers: Record<string, NtMessenger>;
  sort_by_job: BooleanLike;
  alert_silenced: BooleanLike;
  alert_able: BooleanLike;
  sending_and_receiving: BooleanLike;
  open_chat: string;
  selected_photo_path: string | null;
  on_spam_cooldown: BooleanLike;
  virus_attach: BooleanLike;
  sending_virus: BooleanLike;
};

export const NtosMessenger = () => {
  const { data } = useBackend<NtosMessengerData>();
  const {
    saved_chats,
    selected_photo_path,
    open_chat,
    messengers,
    sending_virus,
  } = data;

  let content: JSX.Element;
  if (open_chat !== null && (saved_chats[open_chat] || messengers[open_chat])) {
    const openChat = saved_chats[open_chat];
    const temporaryRecipient = messengers[open_chat];
    content = (
      <ChatScreen
        selectedPhoto={selected_photo_path}
        sendingVirus={!!sending_virus}
        canReply={!!(openChat?.can_reply ?? temporaryRecipient)}
        messages={openChat?.messages ?? []}
        messageDraft={openChat?.message_draft ?? ''}
        recipient={openChat?.recipient ?? temporaryRecipient}
        unreads={openChat?.unread_messages ?? 0}
        chatId={openChat?.ref}
      />
    );
  } else {
    content = <ContactsScreen />;
  }

  return (
    <NtosWindow width={600} height={850}>
      <NtosWindow.Content>{content}</NtosWindow.Content>
    </NtosWindow>
  );
};

const chatToButton = (chat: NtChat) => {
  return (
    <ChatButton
      key={chat.ref}
      name={`${chat.recipient.name} (${chat.recipient.job})`}
      chatRef={chat.ref}
      unreads={chat.unread_messages}
    />
  );
};

const messengerToButton = (messenger: NtMessenger) => {
  return (
    <ChatButton
      key={messenger.ref}
      name={`${messenger.name} (${messenger.job})`}
      chatRef={messenger.ref!}
      unreads={0}
    />
  );
};

const ContactsScreen = () => {
  const { act, data } = useBackend<NtosMessengerData>();
  const {
    owner,
    alert_silenced,
    alert_able,
    sending_and_receiving,
    saved_chats,
    selected_photo_path,
    messengers,
    sort_by_job,
    can_spam,
    virus_attach,
    sending_virus,
  } = data;

  const [searchUser, setSearchUser] = useState('');
  const [previewingPhoto, setPreviewingPhoto] = useState(false);

  const sortByUnreads = sortBy<NtChat>((chat) => -chat.unread_messages);

  const searchChatByName = createSearch(
    searchUser,
    (chat: NtChat) => chat.recipient.name + chat.recipient.job,
  );
  const searchMessengerByName = createSearch(
    searchUser,
    (messenger: NtMessenger) => messenger.name + messenger.job,
  );

  const openChatsArray = sortByUnreads(Object.values(saved_chats)).filter(
    searchChatByName,
  );

  const filteredChatButtons = openChatsArray
    .filter((c) => c.visible)
    .map(chatToButton);

  const messengerButtons = Object.entries(messengers)
    .filter(
      ([ref, messenger]) =>
        openChatsArray.every((chat) => chat.recipient.ref !== ref) &&
        searchMessengerByName(messenger),
    )
    .map(([_, messenger]) => messenger)
    .map(messengerToButton)
    .concat(openChatsArray.filter((chat) => !chat.visible).map(chatToButton));

  return (
    <Stack fill vertical>
      <Stack.Item>
        <Section>
          <Stack vertical textAlign="center">
            <Box bold>
              <Icon name="address-card" mr={1} />
              SpaceMessenger V6.5.5
            </Box>
            <Box italic opacity={0.3} mt={1}>
              Bringing you spy-proof communications since 2467.
            </Box>
            <Divider hidden />
            <Box>
              <Button
                icon="bell"
                disabled={!alert_able}
                onClick={() => act('PDA_toggleAlerts')}
              >
                {alert_able && !alert_silenced ? 'Ringer: On' : 'Ringer: Off'}
              </Button>
              <Button
                icon="address-card"
                onClick={() => act('PDA_toggleSendingAndReceiving')}
              >
                {sending_and_receiving
                  ? 'Send / Receive: On'
                  : 'Send / Receive: Off'}
              </Button>
              <Button icon="bell" onClick={() => act('PDA_ringSet')}>
                Set Ringtone
              </Button>
              <Button icon="sort" onClick={() => act('PDA_changeSortStyle')}>
                {`Sort by: ${sort_by_job ? 'Job' : 'Name'}`}
              </Button>
              {!!virus_attach && (
                <Button
                  icon="bug"
                  color="bad"
                  onClick={() => act('PDA_toggleVirus')}
                >
                  {`Attach Virus: ${sending_virus ? 'Yes' : 'No'}`}
                </Button>
              )}
            </Box>
          </Stack>
          <Divider hidden />
          <Stack justify="space-between">
            <Box m={0.5}>
              <Icon name="magnifying-glass" mr={1} />
              Search For User
            </Box>
            <Input
              width="220px"
              placeholder="Search by name or job..."
              value={searchUser}
              onInput={(_, value) => setSearchUser(value)}
            />
          </Stack>
        </Section>
      </Stack.Item>
      {filteredChatButtons.length > 0 && (
        <Stack.Item grow={1}>
          <Stack vertical fill>
            <Section>
              <Icon name="comments" mr={1} />
              Previous Messages
            </Section>
            <Section fill scrollable>
              <Stack vertical>{filteredChatButtons}</Stack>
            </Section>
          </Stack>
        </Stack.Item>
      )}
      <Stack.Item grow={2}>
        <Stack vertical fill>
          <Section>
            <Stack>
              <Box m={0.5}>
                <Icon name="address-card" mr={1} />
                Detected Messengers
              </Box>
            </Stack>
          </Section>
          <Section fill scrollable>
            <Stack vertical pb={1} fill>
              {messengerButtons.length === 0 && (
                <Stack align="center" justify="center" fill pl={4}>
                  <Icon color="gray" name="user-slash" size={2} />
                  <Stack.Item fontSize={1.5} ml={3}>
                    No users found.
                  </Stack.Item>
                </Stack>
              )}
              {messengerButtons}
            </Stack>
          </Section>
        </Stack>
      </Stack.Item>
      {!!can_spam && (
        <Stack.Item>
          <SendToAllSection onPreview={() => setPreviewingPhoto(true)} />
        </Stack.Item>
      )}
      {selected_photo_path && previewingPhoto && (
        <PhotoPreview
          img={selected_photo_path}
          buttons={
            <>
              <Button
                color="red"
                icon="xmark"
                onClick={() => {
                  setPreviewingPhoto(false);
                  act('PDA_clearPhoto');
                }}
              >
                Clear Photo
              </Button>
              <Button
                icon="arrow-left"
                onClick={() => setPreviewingPhoto(false)}
              >
                Back
              </Button>
            </>
          }
        />
      )}
      {!owner && <NoIDDimmer />}
    </Stack>
  );
};

type ChatButtonProps = {
  name: string;
  unreads: number;
  chatRef: string;
};

const ChatButton = (props: ChatButtonProps) => {
  const { act } = useBackend();
  const unreadMessages = props.unreads;
  const hasUnreads = unreadMessages > 0;
  return (
    <Button
      icon={hasUnreads && 'envelope'}
      key={props.chatRef}
      fluid
      onClick={() => {
        act('PDA_viewMessages', { ref: props.chatRef });
      }}
    >
      {hasUnreads &&
        `[${unreadMessages <= 9 ? unreadMessages : '9+'} unread message${
          unreadMessages !== 1 ? 's' : ''
        }]`}{' '}
      {props.name}
    </Button>
  );
};

const SendToAllSection = (props: { onPreview: () => void }) => {
  const { data, act } = useBackend<NtosMessengerData>();
  const { on_spam_cooldown, selected_photo_path } = data;

  const [message, setmessage] = useState('');

  return (
    <>
      <Section>
        <Stack justify="space-between">
          <Stack.Item align="center">
            <Icon name="satellite-dish" mr={1} ml={0.5} />
            Send To All
          </Stack.Item>
          <Stack>
            <Stack.Item>
              <Button
                tooltip={selected_photo_path ? 'View photo' : 'Scan photo'}
                icon={selected_photo_path ? 'image' : 'upload'}
                onClick={
                  selected_photo_path
                    ? () => props.onPreview()
                    : () => act('PDA_uploadPhoto')
                }
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="arrow-right"
                disabled={on_spam_cooldown || message === ''}
                tooltip={
                  !!on_spam_cooldown && 'Wait before sending more messages!'
                }
                tooltipPosition="auto-start"
                onClick={() => {
                  act('PDA_sendEveryone', { message: message });
                  setmessage('');
                }}
              >
                Send
              </Button>
            </Stack.Item>
          </Stack>
        </Stack>
      </Section>
      <Section>
        <TextArea
          height={6}
          value={message}
          placeholder="Send message to everyone..."
          onChange={(_, value: string) => setmessage(value)}
        />
      </Section>
    </>
  );
};

const NoIDDimmer = () => {
  return (
    <Dimmer>
      <Stack align="baseline" vertical>
        <Stack.Item ml={-2}>
          <Icon color="red" name="address-card" size={10} />
        </Stack.Item>
        <Stack.Item fontSize="18px">
          Please imprint an ID to contfinue.
        </Stack.Item>
      </Stack>
    </Dimmer>
  );
};
