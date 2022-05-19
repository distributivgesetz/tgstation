import { useBackend, useLocalState } from '../backend';
import {
  Button,
  Section,
  Stack,
  Modal,
  NoticeBox,
  TextArea,
  Dropdown,
  Box,
  Icon,
  BlockQuote,
  Collapsible,
  Divider,
} from '../components';
import { Window } from '../layouts';

const DISPATCH_EMERGENCY_ENGINEERING = 'Engineering';
const DISPATCH_EMERGENCY_MEDICAL = 'Medical';
const DISPATCH_EMERGENCY_SECURITY = 'Security';

const REQ_NORMAL_MESSAGE_PRIORITY = 1;
const REQ_HIGH_MESSAGE_PRIORITY = 2;
const REQ_EXTREME_MESSAGE_PRIORITY = 3;

const RC_HACK_PRIORITY_NORMAL = 0;
const RC_HACK_PRIORITY_EXTENDED = 1;
const RC_HACK_PRIORITY_CUT = 2;

// 0 = main menu,
// 1 = req. assistance, -- obsolete
// 2 = req. supplies -- obsolete
// 3 = relay information -- obsolete
// 4 = write msg
// 5 = choose priority - not used
// 6 = sent successfully
// 7 = sent unsuccessfully
// 8 = view messages
// 9 = authentication before sending
// 10 = send announcement

const RequestsConsole = (_, ctx) => {
  const { act, data } = useBackend(ctx);
  const [selecting, setSelecting] = useLocalState(ctx, 'selecting', false);
  const [creatingMessage, setCreatingMessage] = useLocalState(
    ctx,
    'creatingMessage',
    false
  );
  const [announcing, setAnnouncing] = useLocalState(ctx, 'announcing', false);

  const { announcement_console, silent, announce_cooldown } = data;

  return (
    <Window width={575} height={600}>
      <Window.Content>
        {creatingMessage && <RequestConsoleNewRequestModal />}
        {selecting && <RequestConsoleNewRequestMenu />}
        {announcing && !announce_cooldown && (
          <RequestConsoleAnnouncementModal />
        )}
        <Stack vertical fill>
          <Stack.Item grow>
            <Section
              title="Requests"
              fill
              scrollable
              buttons={
                <Box>
                  {announcement_console ? (
                    <Button
                      disabled={announce_cooldown}
                      onClick={() => setAnnouncing(true)}
                      icon="bullhorn"
                      tooltip={
                        announce_cooldown
                        && 'Wait before you send another announcement!'
                      }>
                      Create Announcement
                    </Button>
                  ) : (
                    ''
                  )}
                  <Button icon="plus" onClick={() => setSelecting(true)}>
                    New Request
                  </Button>
                  <Button
                    tooltip={!silent ? 'Mute' : 'Unmute'}
                    icon={!silent ? 'volume-up' : 'volume-mute'}
                    color={silent && 'red'}
                    onClick={() => act('set_silent', { silent: !silent })}
                  />
                </Box>
              }>
              <RequestConsoleMessages />
            </Section>
          </Stack.Item>

          <Stack.Item>
            <RequestConsoleEmergencyDispatch />
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const RequestConsoleMessages = (_, ctx) => {
  const { act, data } = useBackend(ctx);

  const { messages } = data;

  // deleting messages by their index in the list
  const unarchived = messages
    .map((msg, i) => ({ ...msg, ['id']: i + 1 }))
    .filter((msg) => !msg.archived);
  const archived = messages
    .map((msg, i) => ({ ...msg, ['id']: i + 1 }))
    .filter((msg) => msg.archived);

  return (
    <Stack fill justify="space-between" vertical>
      <Stack.Item>
        <Stack fill vertical>
          {unarchived.length !== 0 ? (
            unarchived.map((msg, index) => (
              <Box key={index}>
                <Stack.Item>
                  <RequestConsoleMessage message={msg} />
                </Stack.Item>
                <Stack.Divider />
              </Box>
            ))
          ) : (
            <span>No new messages.</span>
          )}
        </Stack>
      </Stack.Item>
      <Stack.Item>
        {archived.length !== 0 && (
          <>
            <Divider />
            <Collapsible title="Archived Messages">
              {archived.map(
                (msg, index) =>
                  msg.archived && (
                    <Box key={index}>
                      <Stack.Item>
                        <RequestConsoleMessage message={msg} archived />
                      </Stack.Item>
                      <Stack.Divider />
                    </Box>
                  )
              )}
            </Collapsible>
          </>
        )}
      </Stack.Item>
    </Stack>
  );
};

const RequestConsoleMessage = (props, ctx) => {
  const { act, data } = useBackend(ctx);
  const { message, archived } = props;
  return (
    <Box>
      <Section
        title={
          <span className={archived && 'color-light-grey'}>
            {archived && <i>Archived: </i>}Request for <i>{message.type}</i>{' '}
            from {message.sender}
          </span>
        }
        buttons={
          <>
            {!archived ? (
              <Button
                icon="inbox"
                onClick={() => act('archive_message', { id: message.id })}
                tooltip="Archive"
              />
            ) : (
              <Button
                icon="box"
                onClick={() => act('unarchive_message', { id: message.id })}
                tooltip="Unarchive"
              />
            )}
            <Button.Confirm
              icon="trash"
              tooltip="Delete"
              onClick={() => act('delete_message', { id: message.id })}
            />
          </>
        }>
        <BlockQuote m={1}>
          From {message.authentication} at {message.timestamp} <br />
          {message.priority}
        </BlockQuote>
        <span>{message.body}</span>
      </Section>
    </Box>
  );
};

const RequestConsoleNewRequestModal = (_, ctx) => {
  const { act, data } = useBackend(ctx);
  const [newReq, setNewReq] = useLocalState(ctx, 'req', {});
  const [creatingMessage, setCreatingMessage] = useLocalState(
    ctx,
    'creatingMessage',
    false
  );

  const { current_user, idscan_cut, priority_hack_state } = data;

  const validate = () => {
    if (newReq.body === '') {
      return 'You must write a message!';
    } else if (
      newReq.priority === REQ_EXTREME_MESSAGE_PRIORITY
      && current_user === null
      && !idscan_cut
    ) {
      return 'You must authenticate before sending an extreme priority request!';
    } else {
      return '';
    }
  };

  // Submit request form object
  // DM does not care about auth, otherwise you could spoof it
  const handleRequestSubmit = () => {
    act('submit_new_request', newReq);
    setCreatingMessage(false);
  };

  // Wipe new request form
  const handleRequestCancel = () => {
    setNewReq({
      body: '',
      addressee: '',
      priority: REQ_NORMAL_MESSAGE_PRIORITY,
    });
    setCreatingMessage(false);
  };

  const handlePrioritySelection = (priority) => {
    switch (priority) {
      case 'Normal Priority':
        setNewReq((prev) => ({
          ...prev,
          ['priority']: REQ_NORMAL_MESSAGE_PRIORITY,
        }));
        break;
      case 'High Priority':
        setNewReq((prev) => ({
          ...prev,
          ['priority']: REQ_HIGH_MESSAGE_PRIORITY,
        }));
        break;
      case 'Extreme Priority':
        setNewReq((prev) => ({
          ...prev,
          ['priority']: REQ_EXTREME_MESSAGE_PRIORITY,
        }));
        break;
    }
  };

  const composePriorityList = () => {
    switch (priority_hack_state) {
      case RC_HACK_PRIORITY_NORMAL:
        return ['Normal Priority', 'High Priority'];
      case RC_HACK_PRIORITY_CUT:
        return ['Normal Priority'];
      case RC_HACK_PRIORITY_EXTENDED:
        return ['Normal Priority', 'High Priority', 'Extreme Priority'];
    }
  };

  const renderPriorityText = () => {
    switch (newReq.priority) {
      case REQ_NORMAL_MESSAGE_PRIORITY:
        return <span>Normal Priority</span>;
      case REQ_HIGH_MESSAGE_PRIORITY:
        return <span>High Priority</span>;
      case REQ_EXTREME_MESSAGE_PRIORITY:
        return <span className="text-italic">Extreme Priority</span>;
    }
  };

  // awful nesting, but tgui has forced my hand
  return (
    <Modal textAlign="left" width={35}>
      <Section title={`Send Request To ${newReq.addressee}`} height={22} fill>
        <Stack fill vertical justify="space-between">
          <Stack.Item>
            <Stack fill vertical>
              {/* Authentication */}
              <Stack.Item>
                <NoticeBox
                  info={current_user !== null}
                  danger={idscan_cut}
                  mb={0}>
                  {!idscan_cut
                    ? current_user
                      ? `As ${current_user}`
                      : 'Identification not found!'
                    : 'Identification not found! Contact an engineer!'}
                </NoticeBox>
              </Stack.Item>
              {/* Message Body */}
              <Stack.Item>
                <Box>
                  <TextArea
                    fluid
                    height="90px"
                    width="340px"
                    backgroundColor="black"
                    textColor="white"
                    maxLength={512}
                    placeholder="Write a message..."
                    onInput={(e) =>
                      setNewReq((prev) => ({
                        ...prev,
                        ['body']: e.target.value,
                      }))}
                  />
                </Box>
              </Stack.Item>
              {/* Message Priority */}
              <Stack.Item>
                <Box height={2}>
                  <Dropdown
                    options={composePriorityList()}
                    noscroll
                    width={15}
                    selected={renderPriorityText()}
                    onSelected={handlePrioritySelection}
                  />
                </Box>
              </Stack.Item>
              {newReq.priority === REQ_EXTREME_MESSAGE_PRIORITY ? (
                <Stack.Item>
                  <NoticeBox>
                    Misuse of this function will incur sanctions.
                    {current_user === null && ' Authentication is required.'}
                  </NoticeBox>
                </Stack.Item>
              ) : (
                ''
              )}
              <Stack.Item />
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Box>
              <Stack>
                <Stack.Item>
                  <Button
                    onClick={() => handleRequestSubmit()}
                    disabled={validate() !== ''}
                    tooltip={validate()}
                    color="green">
                    Send Message
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => handleRequestCancel()} color="red">
                    Cancel
                  </Button>
                </Stack.Item>
              </Stack>
            </Box>
          </Stack.Item>
        </Stack>
      </Section>
    </Modal>
  );
};

const RequestConsoleNewRequestMenu = (_, ctx) => {
  const { act, data } = useBackend(ctx);

  const [creatingMessage, setCreatingMessage] = useLocalState(
    ctx,
    'creatingMessage',
    false
  );
  const [newReq, setNewReq] = useLocalState(ctx, 'req', {});
  const [selecting, setSelecting] = useLocalState(ctx, 'selecting', false);

  const { rc_supplies, rc_assistance } = data;

  const newMessageAssistance = (rc) => {
    setNewReq({
      type: 'Assistance',
      body: '',
      addressee: rc,
      priority: REQ_NORMAL_MESSAGE_PRIORITY,
    });
    setCreatingMessage(true);
    setSelecting(false);
  };

  const newMessageSupplies = (rc) => {
    setNewReq({
      type: 'Supplies',
      body: '',
      addressee: rc,
      priority: REQ_NORMAL_MESSAGE_PRIORITY,
    });
    setCreatingMessage(true);
    setSelecting(false);
  };

  return (
    <Modal width={45}>
      <Section
        title="Create New Request"
        buttons={<Button onClick={() => setSelecting(false)}>Go Back</Button>}>
        <Stack fill>
          <Stack.Item grow>
            <Section title="Supplies" fill>
              <Stack vertical>
                {rc_supplies.map((rc, i) => {
                  return (
                    <Stack.Item key={i}>
                      <Button onClick={() => newMessageSupplies(rc)}>
                        {rc}
                      </Button>
                    </Stack.Item>
                  );
                })}
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Section title="Assistance" style={{ overflow: 'hidden' }}>
              <Stack vertical>
                {rc_assistance.map((rc, i) => {
                  return (
                    <Stack.Item key={i}>
                      <Button onClick={() => newMessageAssistance(rc)}>
                        {rc}
                      </Button>
                    </Stack.Item>
                  );
                })}
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Section>
    </Modal>
  );
};

const RequestConsoleEmergencyDispatch = (_, ctx) => {
  const { act, data } = useBackend(ctx);
  const [errored, setErrored] = useLocalState(ctx, 'emergency_error', false);

  const { emergency_dispatch, emergency_cut } = data;

  const dispatchEmergency = (dep) => {
    if (emergency_cut) {
      setErrored(true);
      return;
    }
    act('dispatch_emergency', { dep: dep });
  };

  if (errored) {
    return (
      <Section>
        <h3 className="text-center text-italic">
          Dispatch could not be called. Please try again later.
          <br />
          If the problem persists, please contact an engineer.
        </h3>
      </Section>
    );
  }

  if (emergency_dispatch) {
    return (
      <Section>
        <h3 className="color-bad text-center">
          {emergency_dispatch} has been dispatched to your location.
        </h3>
      </Section>
    );
  }

  return (
    <Section title={<h3 className="text-center">Send Emergency Alert</h3>}>
      <Stack>
        <Stack.Item grow>
          <Button
            fluid
            color="orange"
            onClick={() => {
              dispatchEmergency(DISPATCH_EMERGENCY_ENGINEERING);
            }}>
            <Box className="text-center">
              <Icon name="wrench" />
              Engineering
            </Box>
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button
            fluid
            color="blue"
            onClick={() => {
              dispatchEmergency(DISPATCH_EMERGENCY_MEDICAL);
            }}>
            <Box className="text-center">
              <Icon name="star-of-life" />
              Medical
            </Box>
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button
            fluid
            color="red"
            onClick={() => {
              dispatchEmergency(DISPATCH_EMERGENCY_SECURITY);
            }}>
            <Box className="text-center">
              <Icon name="exclamation" />
              Security
            </Box>
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const RequestConsoleAnnouncementModal = (_, ctx) => {
  const { act, data } = useBackend(ctx);
  const [announcing, setAnnouncing] = useLocalState(ctx, 'announcing', false);
  const [announcementBody, setAnnouncementBody] = useLocalState(
    ctx,
    'announcementBody',
    ''
  );

  const { current_user, can_announce, idscan_cut } = data;

  const validate = () => {
    if (!current_user) {
      return 'You must authenticate yourself before sending an announcement!';
    } else if (!can_announce) {
      return 'You do not have permission to make announcements!';
    } else if (announcementBody.length < 4) {
      return 'You must write an announcement!';
    } else {
      return null;
    }
  };

  return (
    <Modal width={30}>
      <Section title="Create Station Announcement" fill height={17}>
        <Stack vertical fill>
          <Stack.Item>
            <NoticeBox
              info={current_user !== null && can_announce}
              danger={idscan_cut}
              mb={0}>
              {!idscan_cut
                ? current_user
                  ? can_announce
                    ? 'Authorization accepted.'
                    : 'Invalid Access!'
                  : 'Identification not found!'
                : 'ID not found! Contact an engineer!'}
            </NoticeBox>
          </Stack.Item>
          <Stack.Item>
            <TextArea
              height={8}
              placeholder="Send a station-wide announcement..."
              onInput={(e) => setAnnouncementBody(e.target.value)}
            />
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item>
                <Button
                  disabled={!!validate()}
                  tooltip={validate()}
                  color="green"
                  onClick={() => {
                    act('send_announcement', { message: announcementBody });
                    setAnnouncing(false);
                  }}>
                  Send
                </Button>
                <Button onClick={() => setAnnouncing(false)} color="red">
                  Cancel
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Section>
    </Modal>
  );
};

export { RequestsConsole };
