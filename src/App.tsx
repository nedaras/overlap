import { createSignal, onCleanup } from 'solid-js'

export default function App() {

  const [ active, setActive ] = createSignal(true)
  const [ shortcut, setShortcut ] = createSignal('')

  chrome.storage.local.get([ 'shortcut' ], ({ shortcut }) => {

    setShortcut(shortcut ? shortcut : 'INSERT')

  })

  function handleInput({ key }: KeyboardEvent) {

    chrome.storage.local.set({ shortcut: key.toUpperCase() }).then(() => setShortcut(key.toUpperCase()))

    window.removeEventListener('keydown', handleInput)

  }

  function selectKey() {

    window.addEventListener('keydown', handleInput)

  }

  onCleanup(() => window.removeEventListener('keydown', handleInput))

  return <>
    <header>

    </header>
    <ul class='select-none' >
      <li class='py-1' >
        <div class='hover:bg-gray-100 px-1' >
          <div class='w-full text-left pl-4' onclick={() => setActive((active) => !active)} >
            { active() ? 'Disable' : 'Activate' }
          </div>
        </div>
      </li>
      <li class='py-1' >
        <div class='hover:bg-gray-100 px-1' >
          <div class='flex justify-between gap-8 w-full text-left pl-4' onClick={selectKey} >
            <div>Shortcut</div>
            <div>{ shortcut() }</div>
          </div>
        </div>
      </li>
    </ul>
  </>

}
