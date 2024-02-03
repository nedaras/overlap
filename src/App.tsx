export default function App() {

  function handleClick() {

    console.log('fuck')

  }

  return <>
    <h1>Overlap</h1>
    <ul>
      <li>
        <button onclick={handleClick} >
          Press Me
        </button>
      </li>
    </ul>
  </>

}
