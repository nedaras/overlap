(() => { // We are wrapping so we would not get variable collisions with the web

  const rotateSVG = '<svg width="20px" height="20px" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M11.5 20.5C6.80558 20.5 3 16.6944 3 12C3 7.30558 6.80558 3.5 11.5 3.5C16.1944 3.5 20 7.30558 20 12C20 13.5433 19.5887 14.9905 18.8698 16.238M22.5 15L18.8698 16.238M17.1747 12.3832L18.5289 16.3542L18.8698 16.238" stroke="#dbdbdb" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path> </g></svg>'
  const deleteSVG = '<svg width="20px" height="20px" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M18 6L17.1991 18.0129C17.129 19.065 17.0939 19.5911 16.8667 19.99C16.6666 20.3412 16.3648 20.6235 16.0011 20.7998C15.588 21 15.0607 21 14.0062 21H9.99377C8.93927 21 8.41202 21 7.99889 20.7998C7.63517 20.6235 7.33339 20.3412 7.13332 19.99C6.90607 19.5911 6.871 19.065 6.80086 18.0129L6 6M4 6H20M16 6L15.7294 5.18807C15.4671 4.40125 15.3359 4.00784 15.0927 3.71698C14.8779 3.46013 14.6021 3.26132 14.2905 3.13878C13.9376 3 13.523 3 12.6936 3H11.3064C10.477 3 10.0624 3 9.70951 3.13878C9.39792 3.26132 9.12208 3.46013 8.90729 3.71698C8.66405 4.00784 8.53292 4.40125 8.27064 5.18807L8 6M14 10V17M10 10V17" stroke="#dbdbdb" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path> </g></svg>'

  /**
   * @param {HTMLElement} element
   * @returns {HTMLElement}
   */
  function applyGlobalStyles(element) // aint so global when using inner html
  {

    element.style.padding = '0'
    element.style.margin = '0'
    element.style.boxSizing = 'border-box'
    element.style.userSelect = 'none'
    element.style.fontFamily = 'sans-serif'

    return element

  }

  /**
   * @param {string} text
   * @returns {string}
   */
  const li = (text) => `<li style="display: grid; place-items: center; width: 40px; height: 40px; border-radius: 15px;">${text}</li>` // TODO: hover effects

  const container = applyGlobalStyles(document.createElement('div'))

  const header = applyGlobalStyles(document.createElement('header'))
  const imageRegion = applyGlobalStyles(document.createElement('div'))
  const image = applyGlobalStyles(document.createElement('img'))

  container.style.position = 'fixed'
  container.style.top = '0'
  container.style.left = '0'
  container.style.zIndex = '999999'
  container.style.width = '100vw'
  container.style.height = '100vh'
  container.style.display = 'flex'
  container.style.justifyContent = 'space-between'
  container.style.flexDirection = 'column'

  header.style.height = '48px'
  header.style.width = '100%'
  header.style.background = '#1f1f1f'
  header.style.display = 'grid'
  header.style.placeItems = 'center'
  header.style.color = '#dbdbdb'

  header.innerHTML = `<ul style="display: flex; list-style: none;">${li(rotateSVG)}${li(deleteSVG)}</ul>`

  imageRegion.style.width = '100%'
  imageRegion.style.height = 'calc(100% - 48px)'
  imageRegion.style.background = '#1f1f1f'
  imageRegion.style.overflow = 'hidden'
  imageRegion.style.display = 'flex'
  imageRegion.style.justifyContent = 'center'
  imageRegion.style.alignItems = 'center'

  imageRegion.innerHTML = `<h1 style="position: absolute; color: #f1f1f1; font-size: 28px;">Drop images in.</h1>`

  image.draggable = false
  image.src = ''
  image.style.maxHeight = '100%'
  image.style.maxWidth = '100%'
  image.style.zIndex = '10'

  imageRegion.appendChild(image)

  container.appendChild(header)
  container.appendChild(imageRegion)

  container.ondrop = (event) => {

    event.preventDefault()

    for (const file of event.dataTransfer.files) {
      
      if (!file.type.startsWith('image/')) continue

      image.src = URL.createObjectURL(file)

    }

  }

  container.addEventListener('wheel', (event) => event.preventDefault())
  container.ondragover = ((event) => event.preventDefault())

  window.addEventListener('keydown', (event) => {

    if (event.key == 'Insert') document.body.appendChild(container)

  })

})()