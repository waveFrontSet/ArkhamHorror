<script lang="ts" setup>
import { onMounted, reactive, ref, computed, provide, onUnmounted, watch } from 'vue'
import GameDetails from '@/arkham/components/GameDetails.vue';
import * as ArkhamGame from '@/arkham/types/Game';
import { JsonDecoder } from 'ts.data.json';
import { EyeIcon, ArrowsRightLeftIcon, BugAntIcon, ExclamationTriangleIcon, BackwardIcon, DocumentTextIcon, BeakerIcon, BoltIcon, DocumentArrowDownIcon } from '@heroicons/vue/20/solid'
import { useWebSocket, useClipboard } from '@vueuse/core'
import { useUserStore } from '@/stores/user'
import * as Arkham from '@/arkham/types/Game'
import { imgsrc } from '@/arkham/helpers';
import { fetchGame, undoChoice } from '@/arkham/api'
import * as Api from '@/arkham/api'
import Draggable from '@/components/Draggable.vue'
import GameLog from '@/arkham/components/GameLog.vue'
import * as Message from '@/arkham/types/Message'
import api from '@/api'
import CardView from '@/arkham/components/Card.vue'
import Menu from '@/components/Menu.vue'
import { useMenu } from '@/composeable/menu'
import { MenuItem } from '@headlessui/vue'
import CardOverlay from '@/arkham/components/CardOverlay.vue'
import StandaloneScenario from '@/arkham/components/StandaloneScenario.vue'
import ScenarioSettings from '@/arkham/components/ScenarioSettings.vue'
import Campaign from '@/arkham/components/Campaign.vue'
import CampaignLog from '@/arkham/components/CampaignLog.vue'
import CampaignSettings from '@/arkham/components/CampaignSettings.vue'
import { Card, cardDecoder, toCardContents } from '@/arkham/types/Card'
import { TarotCard, tarotCardDecoder, tarotCardImage } from '@/arkham/types/TarotCard'
import { useCardStore } from '@/stores/cards'
import { onBeforeRouteLeave } from 'vue-router'
import { useDebug } from '@/arkham/debug'

// Types
interface GameCard {
  title: string
  card: Card
}

interface GameCardOnly {
  player: string
  title: string
  card: Card
}

// TODO: contents should not be string
type ServerResult =
  | { tag: "GameError"; contents: string }
  | { tag: "GameMessage"; contents: string }
  | { tag: "GameTarot"; contents: string }
  | { tag: "GameCard"; contents: string }
  | { tag: "GameCardOnly"; contents: string }
  | { tag: "GameUpdate"; contents: string }

// Setup
export interface Props {
  gameId: string
  spectate?: boolean
}
const props = withDefaults(defineProps<Props>(), { spectate: false })

const debug = useDebug()
const source = ref(`${window.location.href}/join`) // fix-syntax`
const store = useCardStore()
const userStore = useUserStore()
const { copy } = useClipboard({ source })
const { menuItems } = useMenu()

store.fetchCards()

// Refs
const game = ref<Arkham.Game | null>(null)
const gameCard = ref<GameCard | null>(null)
const gameLog = ref<readonly string[]>(Object.freeze([]))
const playerId = ref<string | null>(null)
const ready = ref(false)
const resultQueue = ref<any>([])
const showLog = ref(false);
const showShortcuts = ref(false)
const showSidebar = ref(JSON.parse(localStorage.getItem("showSidebar")??'true'))
const socketError = ref(false)
const solo = ref(false)
const tarotCards = ref<TarotCard[]>([])
const uiLock = ref<boolean>(false)

// Reactive
const preloaded = reactive<string[]>([])

// Computed
const cards = computed(() => store.cards)
const choices = computed(() => {
  if (!game.value || !playerId.value) return []
  return ArkhamGame.choices(game.value, playerId.value)
})
const gameOver = computed(() => game.value?.gameState.tag === "IsOver")
const question = computed(() => playerId.value ? game.value?.question[playerId.value] : null)
const websocketUrl = computed(() => {
  const spectatePrefix = props.spectate ? "/spectate" : ""
  return `${baseURL}/api/v1/arkham/games/${props.gameId}${spectatePrefix}?token=${userStore.token}`.
    replace(/https/, 'wss').
    replace(/http/, 'ws')
})

await fetchGame(props.gameId, props.spectate).then(({ game: newGame, playerId: newPlayerId, multiplayerMode}) => {
  loadAllImages(newGame).then(() => {
    game.value = newGame
    solo.value = multiplayerMode === "Solo"
    gameLog.value = Object.freeze(newGame.log)
    playerId.value = newPlayerId
    ready.value = true
  })
})

// Local Decoders
const gameCardDecoder = JsonDecoder.object<GameCard>(
  {
    title: JsonDecoder.string,
    card: cardDecoder
  },
  'GameCard'
);

const gameCardOnlyDecoder = JsonDecoder.object<GameCardOnly>(
  {
    player: JsonDecoder.string,
    title: JsonDecoder.string,
    card: cardDecoder
  },
  'GameCard'
);

const baseURL = `${window.location.protocol}//${window.location.hostname}${window.location.port ? `:${window.location.port}` : ''}`

// Socket Handling
const onError = () => socketError.value = true
const onConnected = () => socketError.value = false
const { data, send, close } = useWebSocket(websocketUrl.value, { autoReconnect: true, onError, onConnected })
const handleResult = (result: ServerResult) => {
  switch(result.tag) {
    case "GameError":
      alert(result.contents)
      return
    case "GameMessage":
      gameLog.value = Object.freeze([...gameLog.value, result.contents])
      return
    case "GameTarot":
      if (uiLock.value) {
        resultQueue.value.push(result)
      } else {
        JsonDecoder.array(tarotCardDecoder, 'tarotCards').decodeToPromise(result.contents).then((r) => {
          uiLock.value = true
          tarotCards.value = r
        })
      }
      return
    case "GameCard":
      if (uiLock.value) {
        resultQueue.value.push(result)
      } else {
        gameCardDecoder.decodeToPromise(result).then((r) => {
          uiLock.value = true
          gameCard.value = r
        })
      }
      return
    case "GameCardOnly":
      if (uiLock.value) {
        resultQueue.value.push(result)
      } else {
        gameCardOnlyDecoder.decodeToPromise(result).then((r) => {
          if (solo.value === true || r.player == playerId.value) {
            uiLock.value = true
            gameCard.value = r
          }
        })
      }
      return
    case "GameUpdate":
      if (uiLock.value) {
        resultQueue.value.push(result)
        game.value = {...game.value, question: {}} as Arkham.Game
      } else {
        Arkham.gameDecoder.decodeToPromise(result.contents)
          .then((updatedGame) => {
            loadAllImages(updatedGame).then(() => {
              game.value = updatedGame
              gameLog.value = Object.freeze([...updatedGame.log])
              if (solo.value === true) {
                if (Object.keys(game.value.question).length == 1) {
                  playerId.value = Object.keys(game.value.question)[0]
                } else if (game.value.activePlayerId !== playerId.value) {
                  if (playerId.value && Object.keys(game.value.question).includes(playerId.value)) {
                    playerId.value = game.value.activePlayerId
                  } else {
                    playerId.value = Object.keys(game.value.question)[0]
                  }
                } else if (playerId.value && !Object.keys(game.value.question).includes(playerId.value)) {
                    playerId.value = Object.keys(game.value.question)[0]
                }
              }
            })
          })
      }
      return
  }
}
// watchers
watch(data, async (newData) => {
  const result = JSON.parse(newData)
  handleResult(result)
})

watch(uiLock, async () => {
  if (uiLock.value) return
  const r = resultQueue.value.shift()
  if (r) handleResult(r)
})

// Keyboard Shortcuts
const handleKeyPress = (event: KeyboardEvent) => {
  if (filingBug.value) return
  if (event.key === 'u') {
    undo()
    return
  }

  if (event.key === 'D') {
    debug.toggle()
    return
  }

  if (event.key === '?') {
    showShortcuts.value = !showShortcuts.value
    return
  }

  if (event.key === ' ') {
    const skipTriggers = choices.value.findIndex((c) => c.tag === Message.MessageType.SKIP_TRIGGERS_BUTTON)
    if (skipTriggers !== -1) choose(skipTriggers)
    return
  }

  if (event.key === 'd') {
    const draw = choices.value.findIndex((c) => {
      if (c.tag !== Message.MessageType.COMPONENT_LABEL) return false
      if (c.component.tag !== "InvestigatorDeckComponent") return false
      if (!playerId.value) return false
      return game.value?.investigators[c.component.investigatorId]?.playerId === playerId.value
    })
    if (draw !== -1) {
      choose(draw)
    } else {
      const drawEncounter = choices.value.findIndex((c) => {
        if (c.tag !== Message.MessageType.TARGET_LABEL) return false
        return c.target.tag === "EncounterDeckTarget"
      })

      if (drawEncounter !== -1) choose(drawEncounter)
    }
    return
  }

  if (event.key === 'r') {
    const resource = choices.value.findIndex((c) => {
      if (c.tag !== Message.MessageType.COMPONENT_LABEL) return false
      if (c.component.tag !== "InvestigatorComponent") return false
      if (c.component.tokenType !== "ResourceToken") return false
      if (!playerId.value) return false
      return game.value?.investigators[c.component.investigatorId]?.playerId === playerId.value
    })
    if (resource !== -1) choose(resource)
    return
  }

  if (event.key === 'e') {
    const endTurn = choices.value.findIndex((c) => {
      if (c.tag !== Message.MessageType.END_TURN_BUTTON) return false
      return game.value?.investigators[c.investigatorId]?.playerId === playerId.value
    })
    if (endTurn !== -1) choose(endTurn)
    return
  }

  menuItems.value.forEach((item) => {
    if (item.shortcut === event.key) item.action()
  })
}

// Sidebar
const toggleSidebar = function () {
  showSidebar.value = !showSidebar.value
  localStorage.setItem("showSidebar", JSON.stringify(showSidebar.value))
}

// Undo
async function undo() {
  resultQueue.value = []
  gameCard.value = null
  tarotCards.value = []
  uiLock.value = false
  undoChoice(props.gameId)
}

const filingBug = ref(false)
const submittingBug = ref(false)
const bugTitle = ref("")
const bugDescription = ref("")

async function fileBug() {
  submittingBug.value = true
  filingBug.value = false
  Api.fileBug(props.gameId).then((response) => {
    const title = encodeURIComponent(bugTitle.value)
    const body = encodeURIComponent(`${bugDescription.value}\n\nfile: ${response.data}`)
    window.open(`https://github.com/halogenandtoast/ArkhamHorror/issues/new?labels=bug&title=${title}&body=${body}&assignee=halogenandtoast&projects=halogenandtoast/2`, '_blank')
    submittingBug.value = false
  }).catch(() => {
    alert('Unable to file bug')
    submittingBug.value = false
  })
}

const continueUI = () => {
  gameCard.value = null
  tarotCards.value = []
  uiLock.value = false
}

// Image Preloading
function loadAllImages(game: Arkham.Game): Promise<void[]> {
  const images = Object.values(game.cards).map((card) => {
    return new Promise<void>((resolve, reject) => {
      const { cardCode, isFlipped } = toCardContents(card)
      const suffix = isFlipped ? 'b' : ''
      const url = imgsrc(`cards/${cardCode.replace(/^c/, '')}${suffix}.jpg`)
      if (preloaded.includes(url)) return resolve()
      const img = new Image()
      img.src = url
      img.onload = () => {
        preloaded.push(url)
        resolve()
      }
      img.onerror = reject
      })
  })

  return Promise.all(images)
}

// Callbacks
async function choose(idx: number) {
  if (idx !== -1 && game.value && !props.spectate) {
    send(JSON.stringify({tag: 'Answer', contents: { choice: idx , playerId: playerId.value } }))
  }
}

async function chooseDeck(deckId: string): Promise<void> {
  if(game.value && !props.spectate) {
    send(JSON.stringify({tag: 'DeckAnswer', deckId, playerId: playerId.value}))
  }
}

async function choosePaymentAmounts(amounts: Record<string, number>): Promise<void> {
  if(game.value && !props.spectate) {
    send(JSON.stringify({tag: 'PaymentAmountsAnswer', contents: { amounts } }))
  }
}

async function chooseAmounts(amounts: Record<string, number>): Promise<void> {
  if(game.value && !props.spectate) {
    send(JSON.stringify({tag: 'AmountsAnswer', contents: { amounts } }))
  }
}

async function update(state: Arkham.Game) { game.value = state }

function switchInvestigator (newPlayerId: string) { playerId.value = newPlayerId }
function debugExport () {
  fetch(new Request(`${api.defaults.baseURL}/arkham/games/${props.gameId}/export`))
  .then(resp => {
    if (!resp.ok) {
      throw new Error(`HTTP error! status: ${resp.status}`);
    }
    return resp.blob()
  })
  .then(blob => {
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.style.display = 'none'
    a.href = url
    // the filename you want
    a.download = 'arkham-debug.json'
    document.body.appendChild(a)
    a.click()
    window.URL.revokeObjectURL(url)
  })
  .catch((e) => {
    console.log(e)
    alert('Unable to download export')
  })
}

// provides
provide('chooseDeck', chooseDeck)
provide('choosePaymentAmounts', choosePaymentAmounts)
provide('chooseAmounts', chooseAmounts)
provide('switchInvestigator', switchInvestigator)
provide('solo', solo)

// callbacks
onMounted(() => document.addEventListener('keydown', handleKeyPress))
onBeforeRouteLeave(() => close())
onUnmounted(() => {
  document.removeEventListener('keydown', handleKeyPress)
  close()
})

</script>

<template>
  <div v-if="submittingBug" class="column page-container">
    <div class="page-content column">
      <h2 class="title">Submitting bug, this may take several minutes, please wait...</h2>
      <section class="box">
        When this process is done, it will open GitHub in a new window and you will be able to resume your game.
      </section>
    </div>
  </div>
  <div id="game" v-else-if="ready && game && playerId">
    <CardOverlay />
    <Draggable v-if="showShortcuts">
      <template #handle>
        <header>
          <h2>Keyboard Shortcuts</h2>
        </header>
      </template>
      <dl class="shortcuts">
        <dt> </dt>
        <dd>(space) Skip Triggers</dd>
        <dt>u</dt>
        <dd>Undo</dd>
        <dt>D</dt>
        <dd>Toggle Debug</dd>
        <dt>?</dt>
        <dd>Show/Hide Shortcuts</dd>
        <dt>d</dt>
        <dd>Draw from deck / encounter deck</dd>
        <dt>r</dt>
        <dd>Take Resources</dd>
        <dt>e</dt>
        <dd>End Turn</dd>
        <template v-for="item in menuItems" :key="item.id">
          <template v-if="item.shortcut">
            <dt>{{item.shortcut}}</dt>
            <dd>{{item.content}}</dd>
          </template>
        </template>
      </dl>
    </Draggable>
    <Draggable v-if="filingBug">
      <template #handle>
        <header clas="file-a-bug-header">
          <h2>File a Bug</h2>
        </header>
      </template>
     <form @submit.prevent="fileBug" class="column bug-form box">
       <p>This will store the current game state, and fill in a GitHub issue. You will need a GitHub account in order to proceed.</p>
       <p class="warning">Please note that it will take some time to submit the bug and you can not resume playing until it is done.</p>
       <input required type="text" v-model="bugTitle" placeholder="A brief title for the bug" />
       <textarea required v-model="bugDescription" placeholder="A description of what happened"></textarea>
       <div class="buttons">
         <button type="submit">Submit</button>
         <button @click="filingBug = false">Cancel</button>
       </div>
     </form>
    </Draggable>
    <div v-if="socketError" class="socketWarning">
       <p>Your game is out of sync, trying to reconnect...</p>
    </div>
    <div class="game-bar">
      <div class="game-bar-item">
        <div>
          <button @click="showLog = !showLog"><DocumentTextIcon aria-hidden="true" /> {{ showLog ? "Close Log" : "View Log" }}</button>
        </div>
      </div>
      <div>
        <Menu>
          <EyeIcon aria-hidden="true" />
          View
          <template #items>
            <MenuItem v-slot="{ active }">
              <button :class="{ active }" @click="showShortcuts = !showShortcuts">
                <BoltIcon aria-hidden="true" /> Shortcuts <span class="shortcut">?</span>
              </button>
            </MenuItem>
            <template v-for="item in menuItems" :key="item.id">
              <MenuItem v-if="item.nested === 'view'" v-slot="{ active }">
                <button :class="{ active }" @click="item.action">
                  <component v-if="item.icon" v-bind:is="item.icon"></component>
                  {{item.content}}
                  <span v-if="item.shortcut" class="shortcut">{{item.shortcut}}</span>
                </button>
              </MenuItem>
            </template>
          </template>
        </Menu>
      </div>
      <div>
        <Menu>
          <BeakerIcon aria-hidden="true" />
          Debug
          <template #items>
            <MenuItem v-slot="{ active }">
              <button :class="{ active }" @click="debug.toggle"><BugAntIcon aria-hidden="true" /> Toggle Debug <span class="shortcut">D</span></button>
            </MenuItem>
            <MenuItem v-slot="{ active }">
              <button :class="{ active }" @click="debugExport"><DocumentArrowDownIcon aria-hidden="true" /> Debug Export</button>
            </MenuItem>
          </template>
        </Menu>
      </div>
      <div><button @click="undo"><BackwardIcon aria-hidden="true" /> Undo</button></div>
      <div><button @click="filingBug = true"><ExclamationTriangleIcon aria-hidden="true" /> File Bug</button></div>
      <div v-for="item in menuItems" :key="item.id">
        <template v-if="item.nested === null || item.nested === undefined">
          <button @click="item.action">
            <component v-if="item.icon" v-bind:is="item.icon"></component>
            {{item.content}}
          </button>
        </template>
      </div>
      <div class="right">
        <button @click="toggleSidebar"><ArrowsRightLeftIcon aria-hidden="true" /> Toggle Sidebar</button>
      </div>
    </div>
    <div v-if="game.gameState.tag === 'IsPending'" class="invite-container">
      <header>
        <h2>Waiting for more players</h2>
      </header>
      <GameDetails :game="game" id="invite">
        <div v-if="playerId == game.activePlayerId" class="full-width">
          <p>Invite them with this url:</p>
          <div class="invite-link">
            <input type="text" :value="source"><button @click="copy()"><font-awesome-icon icon="copy" /></button>
          </div>
        </div>
      </GameDetails>
    </div>
    <template v-else>
      <CampaignLog v-if="showLog && game !== null" :game="game" :cards="cards" />
      <div v-else class="game-main">
        <div v-if="gameCard" class="revelation">
          <div class="revelation-container">
            <h2>{{gameCard.title}}</h2>
            <div class="revelation-card-container">
              <div class="revelation-card">
                <CardView :game="game" :card="gameCard.card" :playerId="playerId" />
                <img v-if="gameCard.card.tag === 'PlayerCard'" :src="imgsrc('player_back.jpg')" class="card back" />
                <img v-else :src="imgsrc('back.png')" class="card back" />
              </div>
              <button @click="continueUI">OK</button>
            </div>
          </div>
        </div>
        <div v-if="tarotCards.length > 0" class="revelation">
          <div class="revelation-container">
            <div class="revelation-card-container">
              <div class="tarot-cards">
                <div
                    v-for="(tarotCard, idx) in tarotCards"
                    :key="idx"
                    class="tarot-card"
                  >
                  <div class="card-container">
                    <img :src="imgsrc(`tarot/${tarotCardImage(tarotCard)}`)" class="tarot" :class="tarotCard.facing" />
                  </div>
                  <img :src="imgsrc('tarot/back.jpg')" class="card back" />
                </div>
              </div>
              <button @click="continueUI">OK</button>
            </div>
          </div>
        </div>
        <CampaignSettings
          v-if="game.campaign && !gameOver && question && question.tag === 'PickCampaignSettings'"
          :game="game"
          :campaign="game.campaign"
          :playerId="playerId"
        />
        <Campaign
          v-else-if="game.campaign"
          :game="game"
          :gameLog="gameLog"
          :playerId="playerId"
          @choose="choose"
          @update="update"
        />
        <ScenarioSettings
          v-else-if="game.scenario && !gameOver && question && question.tag === 'PickScenarioSettings'"
          :game="game"
          :scenario="game.scenario"
          :playerId="playerId"
        />
        <StandaloneScenario
          v-else-if="game.scenario && !gameOver"
          :game="game"
          :playerId="playerId"
          @choose="choose"
          @update="update"
        />
        <div class="sidebar" v-if="showSidebar && game.scenario !== null && (game.gameState.tag === 'IsActive' || game.gameState.tag === 'IsOver')">
          <GameLog :game="game" :gameLog="gameLog" @undo="undo" />
        </div>
        <div class="game-over" v-if="gameOver">
          <p>Game over</p>
          <CampaignLog v-if="game !== null" :game="game" :cards="cards" />
        </div>
        <div class="sidebar" v-if="game.scenario === null">
          <GameLog :game="game" :gameLog="gameLog" @undo="undo" />
        </div>
      </div>
    </template>
  </div>
</template>

<style lang="scss" scoped>
.action { border: 5px solid $select; border-radius: 15px; }

#game {
  width: 100vw;
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}

.game-main {
  width: 100vw;
  height: calc(100vh - 80px);
  display: flex;
  flex: 1;
}

.socketWarning  {
  backdrop-filter: blur(3px);
  background-color: rgba(0,0,0,0.8);
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  z-index: 100;

  justify-content: center;
  align-items: center;
  justify-self: center;
  align-self: center;

  p {
    padding: 10px;
    background: #FFF;
    border-radius: 4px;
  }
}

.sidebar {
  @media (max-width: 800px) {
    display: none;
  }
  height: 100%;
  width: 25vw;
  max-width: 300px;
  display: flex;
  flex-direction: column;
  background: #d0d9dc;

  @media (prefers-color-scheme: dark) {
    background: #1C1C1C;
  }
}

#invite {
  background-color: #15192C;
  color: white;
  width: 800px;
  margin: 0 auto;
  margin-top: 20px;
  border-radius: 5px;
  text-align: center;
  p { margin: 0; padding: 0; margin-bottom: 20px; font-size: 1.3em; }
}

.invite-container {
  margin-top: 50px;
  h2 {
    color: #656A84;
    margin-left: 10px;
    text-transform: uppercase;
    padding: 0;
    margin: 0;
  }
}

header {
  display: flex;
  flex-direction: column;
}

.invite-link {
  flex: 1;
  input {
    color: #26283B;
    font-size: 1.3em;
    width: 60%;
    border-right: 0;
    border-radius: 3px 0 0 3px;
    padding: 5px;
  }
  button {
    font-size: 1.3em;
    border-radius: 0 3px 3px 0;
    padding: 5px 10px;
    position: relative;

    &:before {
        content: '';
        display: none;
        position: absolute;
        z-index: 9998;
        top: 35px;
        left: 15px;
        width: 0;
        height: 0;

        border-left: 5px solid transparent;
        border-right: 5px solid transparent;
        border-bottom: 5px solid rgba(0,0,0,.72);
    }

    &:after {
      content: 'Copied!';
      display: none;
      position: absolute;
      z-index: 9999;
      top: 40px;
      left: -37px;
      width: 114px;
      height: 36px;

      color: #fff;
      font-size: 10px;
      line-height: 36px;
      text-align: center;

      background: rgba(0,0,0,.72);
      border-radius: 3px;
    }

    &:active, &:focus {
      outline: none;

      &:hover {
        background-color: #eee;

        &:before, &:after {
          display: block;
        }
      }
    }
  }
}

.button-link {
  display: block;
  width: 100%;
  text-decoration: none;
  button {
    display: block;
    width: 100%;
  }
}

header {
  font-family: Teutonic;
  font-size: 2em;
  text-align: center;
}

.game-over {
  flex-grow: 1;
  display: flex;
  flex-direction: column;
  align-items: center;

  p {
    text-transform: uppercase;
    background: rgba(0, 0, 0, 0.5);
    width: 100%;
    padding: 10px 20px;
    color: white;
    text-align: center;
  }
}

@keyframes revelation {
  0% {
    opacity: 0;
    transform: scale(0);
  }

  65% {
    transform: scale(1.3);
  }

  100% {
    opacity: 1;
    transform: scale(1);
  }
}

@keyframes anim {
	0%,
	100% {
		border-radius: 30% 70% 70% 30% / 30% 52% 48% 70%;
		//box-shadow: 10px -2vmin 4vmin LightPink inset, 10px -4vmin 4vmin MediumPurple inset, 10px -2vmin 7vmin purple inset;
	}

	10% {
		border-radius: 50% 50% 20% 80% / 25% 80% 20% 75%;
	}

	20% {
		border-radius: 67% 33% 47% 53% / 37% 20% 80% 63%;
	}

	30% {
		border-radius: 39% 61% 47% 53% / 37% 40% 60% 63%;
		//box-shadow: 20px -4vmin 8vmin hotpink inset, -1vmin -2vmin 6vmin LightPink inset, -1vmin -2vmin 4vmin MediumPurple inset, 1vmin 4vmin 8vmin purple inset;
	}

	40% {
		border-radius: 39% 61% 82% 18% / 74% 40% 60% 26%;
	}

	50% {
		border-radius: 100%;
		//box-shadow: 40px 4vmin 16vmin hotpink inset, 40px 2vmin 5vmin LightPink inset, 40px 4vmin 4vmin MediumPurple inset, 40px 6vmin 8vmin purple inset;
	}

	60% {
		border-radius: 50% 50% 53% 47% / 72% 69% 31% 28%;
	}

	70% {
		border-radius: 50% 50% 53% 47% / 26% 22% 78% 74%;
		//box-shadow: 1vmin 1vmin 8vmin LightPink inset, 2vmin -1vmin 4vmin MediumPurple inset, -1vmin -1vmin 16vmin purple inset;
	}

	80% {
		border-radius: 50% 50% 53% 47% / 26% 69% 31% 74%;
	}

	90% {
		border-radius: 20% 80% 20% 80% / 20% 80% 20% 80%;
	}
}

@property --gradient-angle {
  syntax: "<angle>";
  initial-value: 0deg;
  inherits: false;
}

@keyframes rotation {
  0% { --gradient-angle: 360deg; }
  100% { --gradient-angle: 0deg; }
}

@keyframes glow {
  0% {
    filter: drop-shadow(0 0 3vmin Indigo) drop-shadow(0 5vmin 4vmin Orchid)
      drop-shadow(2vmin -2vmin 15vmin MediumSlateBlue)
      drop-shadow(0 0 7vmin MediumOrchid);
  }
  50% {
    filter: drop-shadow(0 0 3vmin Indigo) drop-shadow(0 5vmin 4vmin Orchid)
      drop-shadow(2vmin -2vmin 15vmin MediumSlateBlue)
      drop-shadow(0 0 7vmin Black);
  }
  100% {
    filter: drop-shadow(0 0 3vmin Indigo) drop-shadow(0 5vmin 4vmin Orchid)
      drop-shadow(2vmin -2vmin 15vmin MediumSlateBlue)
      drop-shadow(0 0 7vmin MediumOrchid);
  }
}

.revelation {
  position: absolute;
  transform: all 0.5s;
  z-index: 1000;
  color: white;
  text-align:center;
  margin: auto;
  inset: 0;
  width: fit-content;
  height: fit-content;
  display: grid;
  // glow effect
  filter: drop-shadow(0 0 3vmin Indigo) drop-shadow(0 5vmin 4vmin Orchid)
		drop-shadow(2vmin -2vmin 15vmin MediumSlateBlue)
		drop-shadow(0 0 7vmin MediumOrchid);
  animation: revelation 0.3s ease-in-out, glow 4s cubic-bezier(0.550, 0.085, 0.680, 0.530) infinite;

  button {
    width: 100%;
    border: 0;
    padding: 10px;
    text-transform: uppercase;
    background-color: #532e61;
    font-weight: bold;
    color: #EEE;
    font: Arial, sans-serif;
    &:hover {
      background-color: #311b3e;
    }

  i {
    font-style: normal;
  }

  .card {
    border-radius: 15px;
  }
}


  h2 {
    font-family: Teutonic;
    text-transform: uppercase;
    margin: 0;
    padding: 0;
    font-size: 2.5em;
  }

  :deep(.card) {
    animation: revelation 0.6s ease-in-out;
    width: 300px !important;
    aspect-ratio: var(--card-ratio);
    overflow: hidden;
    border-radius: 15px;
  }
}

.revelation-container {
  display: flex;
  flex-direction: column;
  gap: 10px;
  align-items: center;
  align-self: center;
  align-content: center;
  justify-content: center;
  justify-items: center;
  justify-self: center;
}

@keyframes flip-back {
  0% {
    opacity: 1;
    transform: rotateY(0deg);
  }

  49% {
    opacity: 1;
  }

  50% {
    opacity: 0;
  }

  100% {
    transform: rotateY(-180deg);
    opacity: 0;
  }
}

@keyframes flip-front {
  0% {
    transform: rotateY(180deg);
    opacity: 0;
  }

  49% {
    opacity: 0;
  }

  50% {
    opacity: 1;
  }

  100% {
    opacity: 1;
    transform: rotateY(0deg);
  }

}


.revelation-card-container {
  display: flex;
  flex-direction: column;
  width: fit-content;
  height: fit-content;
  gap: 10px;

  .tarot-cards {
    gap: 15px;
    display: flex;
    flex-direction: row;
    width: fit-content;
    height: fit-content;
    &:deep(img) {
      border-radius: 10px;
    }
  }

  .revelation-card {
    position: relative;
    width: 300px;
    aspect-ratio: var(--card-aspect);
    perspective: 1000px;
    &:nth-child(1) {
      animation-delay: 0.3s;
    }

    &:nth-child(2) {
      animation-delay: 0.6s;
    }

    &:nth-child(3) {
      animation-delay: 0.9s;
    }

    :deep(.card-container) {
      transform: rotateY(-180deg);
      transform-style: preserve-3d;
      position: absolute;
      top: 0;
      left: 0;
      backface-visibility: hidden;
      animation: flip-front 0.3s linear;
      animation-fill-mode: forwards;
      animation-delay: inherit;
    }

    .card-container {
      opacity: 0;
      transform-style: preserve-3d;
    }

    .card.back {
      transform-style: preserve-3d;
      position: absolute;
      top: 0;
      left: 0;
      backface-visibility: hidden;
      animation: flip-back 0.3s linear;
      animation-fill-mode: forwards;
      animation-delay: inherit;
    }
  }

  .tarot {
    width: 300px;
    aspect-ratio: 8/14;
  }

  .tarot-card:nth-child(1) {
    animation-delay: 0.3s;
  }

  .tarot-card:nth-child(2) {
    animation-delay: 0.6s;
  }

  .tarot-card:nth-child(3) {
    animation-delay: 0.9s;
  }

  .tarot-card {
    position: relative;
    width: 300px;
    padding-bottom: 15px;
    aspect-ratio: 8/14;
    perspective: 1000px;
    .Reversed {
      transform: rotateZ(180deg);
    }
    .card-container {
      transform: rotateY(-180deg);
      transform-style: preserve-3d;
      position: absolute;
      top: 0;
      left: 0;
      backface-visibility: hidden;
      animation: flip-front 0.3s linear;
      animation-fill-mode: forwards;
      animation-delay: inherit;
    }

    img {
      pointer-events: none;
    }

    .card-container {
      opacity: 0;
      transform-style: preserve-3d;
      pointer-events: none;
      img {
        pointer-events: none;
      }
    }

    .card.back {
      transform-style: preserve-3d;
      position: absolute;
      top: 0;
      left: 0;
      backface-visibility: hidden;
      animation: flip-back 0.3s linear;
      animation-fill-mode: forwards;
      animation-delay: inherit;
    }
  }
}

.full-width {
  flex: 1;
  padding-bottom: 10px;
}

.game-bar {
  display: flex;
  margin: 0;
  padding: 0;
  background: var(--background-mid);
  div {
    &.right {
        margin-left: auto;
    }
    display: inline;
    transition: 0.3s;
    height: 100%;
    a {
      display: inline;
    }
    button {
      background: none;
      border: 0;
      display: inline;
      padding: 5px 10px;
      display: flex;
      gap: 5px;
      height: 100%;
      align-items: center;
      svg {
        width: 15px;
      }
      &:hover {
        background: rgba(0,0,0,0.4);
      }
      height: 100%;
    }
  }
  justify-content: flex-start;
}

.game-bar-item.active, .game-bar-item:hover {
  background: rgba(0, 0, 0, 0.21);
  color: var(--title);
}

dl.shortcuts {
  display: grid;
  grid-gap: 4px 16px;
  grid-template-columns: max-content;
  padding: 10px;
  font-size: 1.2em;
  color: white;
  dt {
    font-weight: bold;
    background-color: var(--box-background);
    border: 1px solid var(--title);
    color: white;
    padding: 5px;
    text-align: center;
    aspect-ratio: 1/1;
  }
  dd {
    margin: 0;
    grid-column-start: 2;
    align-self: center;
  }
}

.shortcut {
  margin-left: auto;
  border: 1px solid var(--title);
  background-color: var(--box-background);
  padding: 2px 5px;
  border-radius: 4px;
}

button:hover .shortcut {
  background-color: var(--box-border);
}

.bug-form {
  padding: 10px;
  font-size: 1.2em;
  input, textarea, button {
    font-size: 1.2em;
    padding: 5px 10px;
  }

}
</style>
