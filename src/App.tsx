import { createSignal } from 'solid-js'

export default function App() {

  const [ active, setActive ] = createSignal(true)
  
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
          <div class='flex justify-between gap-8 w-full text-left pl-4' >
            <div>Shortcut</div>
            <div>"key"</div>
          </div>
        </div>
      </li>
    </ul>
  </>

}
