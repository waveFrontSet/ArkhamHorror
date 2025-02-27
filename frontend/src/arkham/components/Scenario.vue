<script lang="ts" setup>
import { EyeIcon, QuestionMarkCircleIcon } from '@heroicons/vue/20/solid'
import {
  watchEffect,
  onMounted,
  onUpdated,
  computed,
  ref,
  ComputedRef,
  reactive,
} from 'vue';
import { type Game } from '@/arkham/types/Game';
import { type Scenario } from '@/arkham/types/Scenario';
import { type Card } from '@/arkham/types/Card';
import { TarotCard, tarotCardImage } from '@/arkham/types/TarotCard';
import { TokenType } from '@/arkham/types/Token';
import { Source } from '@/arkham/types/Source';
import { Message } from '@/arkham/types/Message';
import { waitForImagesToLoad, imgsrc, pluralize } from '@/arkham/helpers';
import { useMenu } from '@/composeable/menu';
import Act from '@/arkham/components/Act.vue';
import CardView from '@/arkham/components/Card.vue';
import Draggable from '@/components/Draggable.vue';
import ChaosBag from '@/arkham/components/ChaosBag.vue';
import Agenda from '@/arkham/components/Agenda.vue';
import Enemy from '@/arkham/components/Enemy.vue';
import CardRow from '@/arkham/components/CardRow.vue';
import Key from '@/arkham/components/Key.vue';
import PlayerTabs from '@/arkham/components/PlayerTabs.vue';
import Connections from '@/arkham/components/Connections.vue';
import PoolItem from '@/arkham/components/PoolItem.vue';
import EncounterDeck from '@/arkham/components/EncounterDeck.vue';
import VictoryDisplay from '@/arkham/components/VictoryDisplay.vue';
import SkillTest from '@/arkham/components/SkillTest.vue';
import ScenarioDeck from '@/arkham/components/ScenarioDeck.vue';
import Story from '@/arkham/components/Story.vue';
import Location from '@/arkham/components/Location.vue';
import * as ArkhamGame from '@/arkham/types/Game';
import { useDebug } from '@/arkham/debug'

// types
interface RefWrapper<T> {
  ref: ComputedRef<T>
}

// Setup
export interface Props {
  game: Game
  scenario: Scenario
  playerId: string
}
const props = defineProps<Props>()
const emit = defineEmits(['choose'])
const debug = useDebug()
const { addEntry, removeEntry } = useMenu()

// emit helpers
const choose = async (idx: number) => emit('choose', idx)

//Refs
const needsInit = ref(true)
const showChaosBag = ref(false)
const showOutOfPlay = ref(false)
const forcedShowOutOfPlay = ref(false)
const locationMap = ref<Element | null>(null)
const viewingDiscard = ref(false)
const cardRowTitle = ref("")
// Atlach Nacha specific refs
const previousRotation = ref(0)
const legsSet = ref(["legs1", "legs2", "legs3", "legs4"])

// callbacks
onMounted(() => {
  if(props.scenario.id === "c06333") {
    waitForImagesToLoad(() => {
      rotateImages(true);
    })
  }
});

onUpdated(() => {
  if(props.scenario.id === "c06333") {
    rotateImages(needsInit.value)
  }
});

// Menu
addEntry({
  id: "viewChaosBag",
  icon: QuestionMarkCircleIcon,
  content: "View Chaos Bag",
  shortcut: "c",
  nested: 'view',
  action: () => showChaosBag.value = !showChaosBag.value
})

// Computed
const scenarioGuide = computed(() => {
  const { reference, difficulty } = props.scenario
  const difficultySuffix = difficulty === 'Hard' || difficulty === 'Expert'
    ? 'b'
    : ''
  return imgsrc(`cards/${reference.replace('c', '')}${difficultySuffix}.jpg`)
})
const scenarioDecks = computed(() => {
  if (!props.scenario.decks) return null
  return Object.entries(props.scenario.decks)
})
const locationStyles = computed(() => {
  const { locationLayout } = props.scenario
  if (!locationLayout) return null
  const cleaned = locationLayout
  return {
    display: 'grid',
    gap: '20px',
    'grid-template-areas': cleaned.map((row) => `"${row}"`).join(' '),
  }
})
const scenarioDeckStyles = computed(() => {
  const { decksLayout } = props.scenario
  return {
    display: 'grid',
    'grid-template-areas': decksLayout.map((row) => `"${row}"`).join(' '),
    'grid-row-gap': '10px',
  }
})
const players = computed(() => props.game.investigators)
const playerOrder = computed(() => props.game.playerOrder)
const discards = computed<Card[]>(() => props.scenario.discard.map(c => ({ tag: 'EncounterCard', contents: c })))
const outOfPlayEnemies = computed(() => {
  const inOutOfPlay = Object.values(props.game.outOfPlayEnemies)
  const other = Object.values(props.game.enemies).filter(e => e.placement.tag === 'OutOfPlay')
  return [...inOutOfPlay, ...other]
})
const outOfPlay = computed(() => props.scenario?.setAsideCards || [])
const removedFromPlay = computed(() => props.game.removedFromPlay)
const noCards = computed<Card[]>(() => [])
const viewUnderScenarioReference = computed(() => `${cardsUnderScenarioReference.value.length} Cards Underneath`)
const viewDiscardLabel = computed(() => pluralize('Card', discards.value.length))
const topOfEncounterDiscard = computed(() => {
  if (!props.scenario.discard[0]) return null
  const { cardCode } = props.scenario.discard[0]
  return imgsrc(`/cards/${cardCode.replace('c', '')}.jpg`)
})
const spectralEncounterDeck = computed(() => props.scenario.encounterDecks['SpectralEncounterDeck']?.[0])
const spectralDiscard = computed(() => props.scenario.encounterDecks['SpectralEncounterDeck']?.[1])
const topOfSpectralDiscard = computed(() => {
  if (!spectralDiscard.value || !spectralDiscard.value[0]) return null
  const { cardCode } = spectralDiscard.value[0]
  return imgsrc(`cards/${cardCode.replace('c', '')}.jpg`)
})
const topEnemyInVoid = computed(() => {
  const inVoidEnemy = Object.values(props.game.enemies).filter((e) => e.placement.tag === 'OutOfPlay' && e.placement.contents == 'VoidZone')[0]
  return inVoidEnemy ?? Object.values(props.game.enemiesInVoid)[0]
})
const activePlayerId = computed(() => props.game.activeInvestigatorId)
const pursuit = computed(() => Object.values(props.game.outOfPlayEnemies).filter((enemy) =>
  enemy.placement.tag === 'OutOfPlay' && enemy.placement.contents === 'PursuitZone'
))
const globalEnemies = computed(() => Object.values(props.game.enemies).filter((enemy) =>
  enemy.placement.tag === "OtherPlacement" && enemy.placement.contents === "Global" && enemy.asSelfLocation === null
))
const globalStories = computed(() => Object.values(props.game.stories).filter((story) =>
  story.placement.tag === "OtherPlacement" && story.placement.contents === "Global"
))
const enemiesAsLocations = computed(() => Object.values(props.game.enemies).filter((enemy) => enemy.asSelfLocation !== null))
const cardsUnderScenarioReference = computed(() => props.scenario.cardsUnderScenarioReference)
const cardsUnderAgenda = computed(() => props.scenario.cardsUnderAgendaDeck)
const cardsUnderAct = computed(() => props.scenario.cardsUnderActDeck)
const cardsNextToAct = computed(() => props.scenario.cardsNextToActDeck)
const cardsNextToAgenda = computed(() => props.scenario.cardsNextToAgendaDeck)
const keys = computed(() => props.scenario.setAsideKeys)
// TODO: not showing cosmos should be more specific, as there could be a cosmos location in the future?
const locations = computed(() => Object.values(props.game.locations).
  filter((a) => a.inFrontOf === null && a.label !== "cosmos"))
const usedLabels = computed(() => locations.value.map((l) => l.label))
const unusedLabels = computed(() => {
  const { locationLayout, usesGrid } = props.scenario;
  if (!locationLayout || !usesGrid) return []
  return locationLayout.flatMap((row) => row.split(' ')).filter((x) => !usedLabels.value.includes(x) && x !== '.')
})
const choices = computed(() => ArkhamGame.choices(props.game, props.playerId))
const resources = computed(() => props.scenario.tokens[TokenType.Resource])
const hasPool = computed(() => resources.value && resources.value > 0)
const tarotCards = computed(() => props.scenario.tarotCards.filter((c) => c.scope.tag === 'GlobalTarot'))
const phase = computed(() => props.game.phase)
const phaseStep = computed(() => props.game.phaseStep)
const currentDepth = computed(() => props.scenario.counts["CurrentDepth"])
const signOfTheGods = computed(() => props.scenario.counts["SignOfTheGods"])
const gameOver = computed(() => props.game.gameState.tag === "IsOver")

// Reactive
const showCards = reactive<RefWrapper<any>>({ ref: noCards })

// Watchers
watchEffect(() => {
  const oop = outOfPlay.value.length + outOfPlayEnemies.value.length
  if (oop == 0) {
    removeEntry("showOutOfPlay")
    showOutOfPlay.value = false
  } else {
    addEntry({
      id: "showOutOfPlay",
      icon: EyeIcon,
      content: "Show Out of Play",
      nested: 'view',
      shortcut: 'o',
      action: () => showOutOfPlay.value = !showOutOfPlay.value
    })
  }
})

watchEffect(() => {
  const isOutOfPlaySource = (source: Source) => {
    switch (source.tag) {
      case "TreacherySource": {
       return outOfPlayEnemies.value.some((e) => {
          if (source.contents) return e.treacheries.includes(source.contents)  
          return false
       })
      }
      default: return false
    }
  }
  const isOutOfPlayChoice = (c: Message) => {
    if (c.tag !== "AbilityLabel") return false 
    return isOutOfPlaySource(c.ability.source)
  }
  const needsShowOutOfPlay = choices.value.some(isOutOfPlayChoice)
  forcedShowOutOfPlay.value = needsShowOutOfPlay
})


// Helpers
function rotateImages(init: boolean) {
  const atlachNacha = document.querySelector('[data-label=atlachNacha]')
  const locationCards = document.querySelector('.location-cards')
  if (atlachNacha && locationCards) {
    needsInit.value = false
    const inLocation = locationCards.querySelector('[data-label=atlachNacha]')

    if (inLocation) {
      ["legs1", "legs2", "legs3", "legs4"].forEach((legs) =>  {
        const legsDiv = locationCards.querySelector(`[data-label=${legs}]`)
        if (!legsDiv) {
          legsSet.value = legsSet.value.filter(item => item !== legs);

          const newDiv = document.createElement('div');
          newDiv.setAttribute('data-label', legs); // Setting the data-label attribute
          newDiv.style.width = '60px'; // Setting the width of the div
          newDiv.style.height = '84px'; // Setting the width of the div
          newDiv.style.gridArea = legs; // Assuming 'legs1' is a valid grid-area name

          locationCards.appendChild(newDiv); // Append the new div to the parent container
        }
      })
    }

    const degrees = parseFloat(atlachNacha.dataset.rotation) || 0
    const middleCardImg = atlachNacha.querySelector('img')
    const middleCardRect = atlachNacha.getBoundingClientRect()
    const middleCardImgRect = middleCardImg.getBoundingClientRect()
    const originX = middleCardImgRect.left + middleCardImgRect.width / 2 - middleCardRect.left
    const originY = middleCardImgRect.top + middleCardImgRect.height / 2 - middleCardRect.top

    if (init) atlachNacha.style.transformOrigin = `${originX}px ${originY}px`
    atlachNacha.style.transition = 'none'
    atlachNacha.style.transform = `rotate(${previousRotation.value}deg)`
    const oX = middleCardImgRect.left + middleCardImgRect.width / 2
    const oY = middleCardImgRect.top + middleCardImgRect.height / 2

    document.querySelectorAll('[data-label=legs1],[data-label=legs2],[data-label=legs3],[data-label=legs4]').forEach((img) => {

      if (init || !legsSet.value.includes(img.dataset.label)) {
        if(!legsSet.value.includes(img.dataset.label)) {
          legsSet.value = [...legsSet.value, img.dataset.label]
        }
        const thisRect = img.getBoundingClientRect()
        const thisX = thisRect.left
        const thisY = thisRect.top
        img.style.transformOrigin = `${oX - thisX}px ${oY - thisY}px`
      }
      img.style.transition = 'none'
      img.style.transform = `rotate(${previousRotation.value}deg)`
    });
    if (degrees !== previousRotation.value) {
      previousRotation.value = degrees
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          atlachNacha.style.transform = `rotate(${previousRotation.value}deg)`
          atlachNacha.style.transition = 'transform 0.5s'
          document.querySelectorAll('[data-label=legs1],[data-label=legs2],[data-label=legs3],[data-label=legs4]').forEach((img) => {
            img.style.transition = 'transform 0.5s'
            img.style.transform = `rotate(${degrees}deg)`
          })
        })
      })
    }
  }
}

function beforeLeave(e: Element) {
  const el = e as HTMLElement
  const {marginLeft, marginTop, width, height} = window.getComputedStyle(el)

  el.style.left = `${el.offsetLeft - parseFloat(marginLeft)}px`
  el.style.top = `${el.offsetTop - parseFloat(marginTop)}px`
  el.style.width = width
  el.style.height = height
}
const doShowCards = (cards: ComputedRef<Card[]>, title: string, isDiscards: boolean) => {
  cardRowTitle.value = title
  showCards.ref = cards
  viewingDiscard.value = isDiscards
}
const showRemovedFromPlay = () => doShowCards(removedFromPlay, 'Removed from Play', true)
const showDiscards = () => doShowCards(discards, 'Discards', true)
const hideCards = () => showCards.ref = noCards
const showCardsUnderScenarioReference = () => doShowCards(cardsUnderScenarioReference, 'Cards Under Scenario Reference', false)
const unusedCanInteract = (u: string) => choices.value.findIndex((c) =>
  c.tag === "GridLabel" && c.gridLabel === u
)
const tarotCardAbility = (card: TarotCard) => {
  return choices.value.findIndex((c) => {
    if (c.tag === "AbilityLabel") {
      return c.ability.source.sourceTag === "TarotSource" && c.ability.source.contents.arcana === card.arcana
    }

    return false
  })
}

</script>

<template>
  <div v-if="!gameOver" id="scenario" class="scenario" :data-scenario="scenario.id">
    <div class="scenario-body">
      <Draggable v-if="showOutOfPlay || forcedShowOutOfPlay">
        <template #handle><header><h2>Out of Play</h2></header></template>
        <div class="card-row-cards">
          <div v-for="card in outOfPlay" :key="card.id" class="card-row-card">
            <CardView :game="game" :card="card" :playerId="playerId" @choose="$emit('choose', $event)" />
          </div>
          <Enemy
            v-for="enemy in outOfPlayEnemies"
            :key="enemy.id"
            :enemy="enemy"
            :game="game"
            :playerId="playerId"
            @choose="choose"
          />
        </div>
        <button v-if="!forcedShowOutOfPlay" class="close" @click="showOutOfPlay = false">Close</button>
      </Draggable>
      <Draggable v-if="showChaosBag">
        <template #handle><header><h2>Chaos Bag</h2></header></template>
        <ChaosBag :game="game" :skillTest="null" :chaosBag="scenario.chaosBag" :playerId="playerId" @choose="choose" />
        <div v-if="debug.active" class="buttons buttons-row">
          <button class="button blessed" @click="debug.send(game.id, {tag: 'AddChaosToken', contents: 'BlessToken'})">Add <span class="bless-icon"></span></button>
          <button class="button cursed" @click="debug.send(game.id, {tag: 'AddChaosToken', contents: 'CurseToken'})">Add <span class="curse-icon"></span></button>
        </div>
        <button class="button" @click="showChaosBag = false">Close</button>
      </Draggable>
      <CardRow
        v-if="showCards.ref.length > 0"
        :game="game"
        :cards="showCards.ref"
        :isDiscards="viewingDiscard"
        :title="cardRowTitle"
        :playerId="playerId"
        @choose="choose"
        @close="hideCards"
      />
      <div class="scenario-cards">
        <div v-if="tarotCards.length > 0" class="tarot-cards">
          <div
            v-for="tarotCard in tarotCards"
            :key="tarotCard.arcana"
            class="tarot-card-container"
            :class="{ [tarotCard.facing]: true, 'can-interact': tarotCardAbility(tarotCard) !== -1 }"
            @click="choose(tarotCardAbility(tarotCard))"
          >
            <img :src="imgsrc(`tarot/${tarotCardImage(tarotCard)}`)" :class="tarotCard.facing" class="card tarot-card" />
          </div>
        </div>
        <div v-if="topEnemyInVoid">
          <Enemy
            :enemy="topEnemyInVoid"
            :game="game"
            :playerId="playerId"
            @choose="choose"
          />
        </div>
        <ScenarioDeck
          :deck="scenarioDeck"
          :key="scenarioDeck[0]"
          v-for="[,scenarioDeck] in scenarioDecks"
        />
        <VictoryDisplay :game="game" :victoryDisplay="scenario.victoryDisplay" @show="doShowCards" :playerId="playerId" />
        <div class="scenario-encounter-decks">

          <div v-if="topOfEncounterDiscard" class="discard" style="grid-area: encounterDiscard">
            <div class="discard-card">
              <img
                :src="topOfEncounterDiscard"
                class="card"
              />
            </div>


            <div v-if="discards.length > 0" class="buttons">
              <button v-if="discards.length > 0" class="view-discard-button" @click="showDiscards">{{viewDiscardLabel}}</button>
              <template v-if="debug.active">
                <button @click="debug.send(game.id, {tag: 'ShuffleEncounterDiscardBackIn'})">Shuffle Back In</button>
              </template>
            </div>
          </div>

          <EncounterDeck
            :game="game"
            :playerId="playerId"
            @choose="choose"
            style="grid-area: encounterDeck"
            v-if="props.scenario.hasEncounterDeck"
          />

          <div v-if="topOfSpectralDiscard" class="discard" style="grid-area: spectralDiscard"
            >
            <img
              :src="topOfSpectralDiscard"
              class="card"
            />
          </div>


          <EncounterDeck
            v-if="spectralEncounterDeck"
            :spectral="spectralEncounterDeck.length"
            :game="game"
            :playerId="playerId"
            @choose="choose"
            style="grid-area: spectralDeck"
          />
        </div>

        <div class="scenario-decks" :style="scenarioDeckStyles">
          <Agenda
            v-for="(agenda, key) in game.agendas"
            :key="key"
            :agenda="agenda"
            :cardsUnder="cardsUnderAgenda"
            :cardsNextTo="cardsNextToAgenda"
            :game="game"
            :playerId="playerId"
            :style="{ 'grid-area': `agenda${agenda.deckId}`, 'justify-self': 'center' }"
            @choose="choose"
            @show="doShowCards"
          />

          <Act
            v-for="(act, key) in game.acts"
            :key="key"
            :act="act"
            :cardsUnder="cardsUnderAct"
            :cardsNextTo="cardsNextToAct"
            :game="game"
            :playerId="playerId"
            :style="{ 'grid-area': `act${act.deckId}`, 'justify-self': 'center' }"
            @choose="choose"
            @show="doShowCards"
          />
        </div>

        <Enemy
          v-for="enemy in pursuit"
          :key="enemy.id"
          :enemy="enemy"
          :game="game"
          :playerId="playerId"
          @choose="choose"
        />

        <Enemy
          v-for="enemy in globalEnemies"
          :key="enemy.id"
          :enemy="enemy"
          :game="game"
          :playerId="playerId"
          @choose="choose"
        />

        <Story
          v-for="story in globalStories"
          :key="story.id"
          :story="story"
          :game="game"
          :playerId="playerId"
          @choose="choose"
        />

        <div class="scenario-guide">
          <img
            class="card"
            :src="scenarioGuide"
          />
          <PoolItem class="depth" v-if="currentDepth" type="resource" :amount="currentDepth" />
          <PoolItem class="signOfTheGods" v-if="signOfTheGods" type="resource" :amount="signOfTheGods" />
          <div class="pool" v-if="hasPool">
            <PoolItem v-if="resources && resources > 0" type="resource" :amount="resources" />
          </div>
          <div class="keys" v-if="keys.length > 0">
            <Key v-for="key in keys" :key="key" :name="key" />
          </div>
          <button v-if="cardsUnderScenarioReference.length > 0" class="view-cards-under-button" @click="showCardsUnderScenarioReference">{{viewUnderScenarioReference}}</button>
        </div>
        <SkillTest
            v-if="game.skillTest"
            :game="game"
            :chaosBag="scenario.chaosBag"
            :skillTest="game.skillTest"
            :playerId="playerId"
            @choose="choose"
        >
        </SkillTest>

        <button v-if="removedFromPlay.length > 0" class="view-removed-from-play-button" @click="showRemovedFromPlay"><font-awesome-icon icon="eye" /> Removed from Play</button>
      </div>

      <Connections :game="game" :playerId="playerId" />

      <div class="location-cards-container">
        <transition-group name="map" tag="div" ref="locationMap" class="location-cards" :style="locationStyles" @before-leave="beforeLeave">
          <Location
            v-for="location in locations"
            class="location"
            :key="location.label"
            :game="game"
            :playerId="playerId"
            :location="location"
            :style="{ 'grid-area': location.label, 'justify-self': 'center' }"
            @choose="choose"
          />
          <Enemy
            v-for="enemy in enemiesAsLocations"
            :key="enemy.id"
            :enemy="enemy"
            :game="game"
            :playerId="playerId"
            :data-label="enemy.asSelfLocation"
            :data-rotation="enemy.meta?.rotation ?? null"
            :style="{ 'grid-area': enemy.asSelfLocation, 'justify-self': 'center', 'align-items': 'center' }"
            @choose="choose"
          />

          <template v-if="scenario.usesGrid">
            <template v-for="u in unusedLabels" :key="u">
              <div
                v-if="unusedCanInteract(u) !== -1"
                class="empty-grid-position card"
                :class="{ 'can-interact': unusedCanInteract(u) !== -1}"
                :style="{ 'grid-area': u}"
                @click="choose(unusedCanInteract(u))"
                >
              </div>
            </template>
          </template>
        </transition-group>
      </div>

      <PlayerTabs
        :game="game"
        :playerId="playerId"
        :players="players"
        :playerOrder="playerOrder"
        :activePlayerId="activePlayerId"
        :tarotCards="props.scenario.tarotCards"
        @choose="choose"
      />
    </div>
    <div class="phases">
      <div class="phase" :class="{ 'active-phase': phase == 'MythosPhase' }">
        <div class="subphases">
          <div v-tooltip.left="'Round begins. Mythos phase begins.'" :class="{'current': phaseStep?.contents === 'MythosPhaseBeginsStep' }">1.1</div>
          <div v-tooltip.left="'Place 1 doom on the current agenda.'" :class="{'current': phaseStep?.contents === 'PlaceDoomOnAgendaStep'}">1.2</div>
          <div v-tooltip.left="'Check doom threshold.'" :class="{'current': phaseStep?.contents === 'CheckDoomThresholdStep'}">1.3</div>
          <div v-tooltip.left="'Each investigator draws 1 encounter card.'" :class="{'current': phaseStep?.contents === 'EachInvestigatorDrawsEncounterCardStep'}">1.4</div>
          <div v-tooltip.left="'PLAYER WINDOW'" :class="{'current': phaseStep?.contents === 'MythosPhaseWindow'}"><i class="fast-icon" /></div>
          <div v-tooltip.left="'Mythos phase ends.'" :class="{'current': phaseStep?.contents === 'MythosPhaseEndsStep'}">1.5</div>
        </div>
        <div>Mythos</div>
      </div>
      <div class="phase" :class="{ 'active-phase': phase == 'InvestigationPhase' }">
        <div class="subphases">
          <div v-tooltip.left="'Investigation phase begins.'" :class="{'current': phaseStep?.contents === 'InvestigationPhaseBeginsStep'}">2.1</div>
          <div v-tooltip.left="'PLAYER WINDOW'" :class="{'current': phaseStep?.contents === 'InvestigationPhaseBeginsWindow'}"><i class="fast-icon" /></div>
          <div v-tooltip.left="'Next investigator\'s turn begins.'" :class="{'current': phaseStep?.contents === 'NextInvestigatorsTurnBeginsStep'}">2.2</div>
          <div v-tooltip.left="'PLAYER WINDOW'" :class="{'current': phaseStep?.contents === 'NextInvestigatorsTurnBeginsWindow'}"><i class="fast-icon" /></div>
          <div v-tooltip.left="'Active investigator may take an action, if able. If an action was taken, return to previous player window. If no action was taken, proceed to 2.2.2.'" :class="{'current': phaseStep?.contents === 'InvestigatorTakesActionStep'}">2.2.1</div>
          <div v-tooltip.left="'Investigator\'s turn ends. If an investigator has not yet taken a turn this phase, return to 2.2. If each investigator has taken a turn this phase, proceed to 2.3.'" :class="{'current': phaseStep?.contents === 'InvestigatorsTurnEndsStep'}">2.2.2</div>
          <div v-tooltip.left="'Investigation phase ends.'" :class="{'current': phaseStep?.contents === 'InvestigationPhaseEndsStep'}">2.3</div>
        </div>
        <div>Investigation</div>
      </div>
      <div class="phase" :class="{ 'active-phase': phase == 'EnemyPhase' }">
        <div class="subphases">
          <div v-tooltip.left="'Enemy phase begins.'" :class="{'current': phaseStep?.contents === 'EnemyPhaseBeginsStep'}">3.1</div>
          <div v-tooltip.left="'Hunter enemies move.'" :class="{'current': phaseStep?.contents === 'HunterEnemiesMoveStep'}">3.2</div>
          <div v-tooltip.left="'PLAYER WINDOW'" :class="{'current': phaseStep?.contents === 'ResolveAttacksWindow'}"><i class="fast-icon" /></div>
          <div v-tooltip.left="'Next investigator resolves engaged enemy attacks. If an investigator has not yet resolved enemy attacks this phase, return to previous player window. After final investigator resolves engaged enemy attacks, proceed to next player window.'" :class="{'current': phaseStep?.contents === 'ResolveAttacksStep'}">3.3</div>
          <div v-tooltip.left="'PLAYER WINDOW'" :class="{'current': phaseStep?.contents === 'AfterResolveAttacksWindow'}"><i class="fast-icon" /></div>
          <div v-tooltip.left="'Enemy phase ends.'" :class="{'current': phaseStep?.contents === 'EnemyPhaseEndsStep'}">3.4</div>
        </div>
        <div>Enemy</div>
      </div>
      <div class="phase" :class="{ 'active-phase': phase == 'UpkeepPhase' }">
        <div class="subphases">
          <div v-tooltip.left="'Upkeep phase begins.'" :class="{'current': phaseStep?.contents === 'UpkeepPhaseBeginsStep'}">4.1</div>
          <div v-tooltip.left="'PLAYER WINDOW'" :class="{'current': phaseStep?.contents === 'UpkeepPhaseBeginsWindow'}"><i class="fast-icon" /></div>
          <div v-tooltip.left="'Reset actions.'" :class="{'current': phaseStep?.contents === 'ResetActionsStep'}">4.2</div>
          <div v-tooltip.left="'Ready each exhausted card.'" :class="{'current': phaseStep?.contents === 'ReadyExhaustedStep'}">4.3</div>
          <div v-tooltip.left="'Each investigator draws 1 card and gains 1 resource.'" :class="{'current': phaseStep?.contents === 'DrawCardAndGainResourceStep'}">4.4</div>
          <div v-tooltip.left="'Each investigator checks hand size.'" :class="{'current': phaseStep?.contents === 'CheckHandSizeStep'}">4.5</div>
          <div v-tooltip.left="'Upkeep phase ends. Round ends.'" :class="{'current': phaseStep?.contents === 'UpkeepPhaseEndsStep'}">4.6</div>
        </div>
        <div>Upkeep</div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.card {
  border-radius: 5px;
  width: var(--card-width);
  height: auto;
  aspect-ratio: var(--card-aspect);
  box-shadow: 1px 1px 6px rgba(0, 0, 0, 0.45);
}

.card--sideways {
  width: auto;
  height: calc(var(--card-width) * 2);
  aspect-ratio: var(--card-sideways-ratio);
}

.scenario-cards {
  display: flex;
  align-self: center;
  align-items: flex-start;
  justify-content: center;
  padding: 10px 0;
  position: relative;
  width: 100%;
  gap: 10px;
  z-index: -2;
}

.clue {
  position: relative;
  width: 57px;
  height: 54px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: black;
  font-weight: 900;
  font-size: 1.5em;

  img {
    position: absolute;
    top: 0;
    bottom: 0;
    left: 0;
    right: 0;
    margin: auto;
    z-index: -1;
  }
}

.scenario-body {
  display: flex;
  flex-direction: column;
  background: var(--background);
  z-index: 1;
  width: 100%;
  flex: 1;
  inset: 0;
}

.location-cards {
  display: flex;
  width: fit-content;
  height: fit-content;
  margin: auto;
}

.location-cards-container {
  display: flex;
  flex: 1;
  scrollbar-gutter: stable both-edges;
  overflow-y: auto;
  padding-top: 32px;
  padding-bottom: 32px;
}

.portrait {
  border-radius: 3px;
}

.portrait--can-move {
  cursor: pointer;
  border: 3px solid $select;
}

.location--can-move-to {
  border: 3px solid $select;
  cursor: pointer;
}

.agenda-container, .act-container {
  align-self: flex-start;
}

.discard {
  height: 100%;
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 5px;
  &:deep(.card) {
    margin: 0;
    box-shadow: none;
  }
  .buttons {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }
}

.discard-card {
  position: relative;
  width: fit-content;
  line-height: 0;
  box-shadow: 1px 1px 6px rgba(0, 0, 0, 0.45);
  .card {
    box-shadow: unset;
  }
  &::after {
    border-radius: 6px;
    pointer-events: none;
    content: "";
    position: absolute;
    inset: 0;
    background-color: #FFF;
    opacity: .85;
    mix-blend-mode: saturation;
  }
}


.view-out-of-play-button {
  text-decoration: none;
  position: absolute;
  transform: translate(100%, -50%) rotate(90deg) translate(0%, 50%) translate(0%, 10px);
  svg {
    transform: rotate(-90deg)
  }
  transform-origin: center left;
  top: 0px;
  right: 0px;
  border: 0;
  color: white;
  background: var(--background-mid);
  font-size: 1.2em;
  padding: 5px 15px;
}

.view-removed-from-play-button {
  text-decoration: none;
  position: absolute;
  transform: translate(100%, -50%) rotate(90deg) translate(0%, 50%) translate(0%, 50px);
  svg {
    transform: rotate(-90deg)
  }
  transform-origin: center left;
  top: 0px;
  right: 0px;
  border: 0;
  color: white;
  background: #a5b5bc;
  font-size: 1.2em;
  padding: 5px 15px;
}

.phases {
  display: flex;
  align-items: flex-end;
  writing-mode: vertical-rl;
  text-orientation: mixed;
  justify-content: space-around;
  background-color: #b8c1c6;
  text-transform: uppercase;
  font-family: Arial;
  > div {
    flex: 1;
    text-align: center;
  }
}


.phase {
  display: flex;
  flex-direction: column;
  width: 100%;
}

.subphases {
  position: relative;
  font-size: 0.7em;
  flex: 1;
  writing-mode: lr-tb;
  text-orientation: revert;
  display: flex;
  min-width: min-content;
  flex-direction: column;
  height: 100%;
  justify-content: space-around;
  color: #b8c1c6;
  background: #484E51;
  text-transform: uppercase;
  font-family: Arial;
  .current {
    background: rgba(0, 0, 0, 0.5) !important;
  }
  > div {
    width: 100%;
    padding: 0 5px;
    display: flex;
    justify-content: center;
    flex: 1;
    align-items: center;
    &:hover {
      background: rgba(0, 0, 0, 0.5);
    }
  }
  > div:nth-of-type(2n) {
    background: lighten(#484E51, 10%);
    &:hover {
      background: rgba(0, 0, 0, 0.5);
    }
  }
}

.scenario {
  display: flex;
  user-select: none;
  width: 100%;
  height: 100%;
  flex: 1;
}

.active-phase {
  font-weight: bold;
  background-color: #8e9ca4;
}

.scenario-guide {
  display: flex;
  flex-direction: column;
  position: relative;
  .depth {
    position: absolute;
    bottom: 0;
    right: 0;
    pointer-events: none;
  }

  .signOfTheGods {
    position: absolute;
    bottom: 0;
    right: 0;
    pointer-events: none;
  }
}

.map-move {
  transition: all 0.6s cubic-bezier(0.23, 1, 0.32, 1);
}

.map-leave-to {
  opacity: 0;
}

.map-leave-active {
  position: absolute;
}

.scenario-decks {
  gap: 5px;
}

.scenario-encounter-decks {
  display: grid;
  grid-template: "encounterDiscard encounterDeck" "spectralDiscard spectralDeck";
  gap: 10px;
}

.empty-grid-position {
  content: " ";
  box-shadow: unset;
}

.can-interact {
  background: rgba(0, 0, 0, 0.5);
  outline: 2px solid $select;
  cursor: pointer;
}

.pool {
  position: absolute;
  top: 10%;
  align-items: center;
  display: flex;
  align-self: flex-start;
  align-items: flex-end;
  * {
    transform: scale(0.6);
  }

  pointer-events: none;
}

.tarot-card {
  width: var(--card-width);
  aspect-ratio: var(--card-tarot-aspect);
  margin: 0;
}

.tarot-card-choices {
  background: url("/img/arkham/background.jpg");
  background-position: center;
  background-size: contain;
  position: absolute;
  z-index: 1000;
  margin: auto;
  inset: 0;
  width: fit-content;
  height: fit-content;
  display: flex;
  gap: 10px;
  padding: 10px;
}

.tarot-card-container {
  transition: transform 0.5s ease-in-out;
  display:flex;
  position: relative;
  border-radius: 5px;

  &.Reversed {
    transform: rotateZ(180deg);
    &:before {
      transform-origin: center;
      animation-fill-mode: forwards;
      animation: shadow-rotate 0.5s linear;
      transform: translate(0, -12px);
    }
  }
}

@keyframes shadow-rotate {
  0% {
    transform: translate(0, 12px);
  }
  25% {
    transform: translate(6px, 12px);
  }
  50% {
    transform: translate(12px, 0px);
  }
  75% {
    transform: translate(6px, -12px);
  }
  100% {
    transform: translate(0, -12px);
  }
}

.tarot-cards {
  display: flex;
  gap: 10px;
  margin-inline: 10px;
}

// We lower the margin so things line up a bit better.
[data-scenario='c06333'] .location-cards:deep(.location-container) {
margin: 20px !important;
}

.buttons-row {
  display: flex;
  flex-direction: row;

  .blessed {
    background-color: var(--blessed);
  }

  .cursed {
    background-color: var(--cursed);
  }
}

.button {
  padding: 5px 10px;
  font-size: 1em;
}

.card-row-cards {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 10px;
  gap: 2px;
  flex-wrap: wrap;
  .card-row-card {
    position: relative;
  }
}

.location {
  &:hover {
    z-index: 100;
  }
}
</style>
