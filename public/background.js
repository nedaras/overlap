(() => { // We are wrapping so we would not get variable collisions with the web

  // ON DELFI ITS FUCKED

  const rotateSVG = '<svg width="20px" height="20px" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M11.5 20.5C6.80558 20.5 3 16.6944 3 12C3 7.30558 6.80558 3.5 11.5 3.5C16.1944 3.5 20 7.30558 20 12C20 13.5433 19.5887 14.9905 18.8698 16.238M22.5 15L18.8698 16.238M17.1747 12.3832L18.5289 16.3542L18.8698 16.238" stroke="#dbdbdb" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path> </g></svg>'
  const deleteSVG = '<svg width="20px" height="20px" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M18 6L17.1991 18.0129C17.129 19.065 17.0939 19.5911 16.8667 19.99C16.6666 20.3412 16.3648 20.6235 16.0011 20.7998C15.588 21 15.0607 21 14.0062 21H9.99377C8.93927 21 8.41202 21 7.99889 20.7998C7.63517 20.6235 7.33339 20.3412 7.13332 19.99C6.90607 19.5911 6.871 19.065 6.80086 18.0129L6 6M4 6H20M16 6L15.7294 5.18807C15.4671 4.40125 15.3359 4.00784 15.0927 3.71698C14.8779 3.46013 14.6021 3.26132 14.2905 3.13878C13.9376 3 13.523 3 12.6936 3H11.3064C10.477 3 10.0624 3 9.70951 3.13878C9.39792 3.26132 9.12208 3.46013 8.90729 3.71698C8.66405 4.00784 8.53292 4.40125 8.27064 5.18807L8 6M14 10V17M10 10V17" stroke="#dbdbdb" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></path> </g></svg>'

  /** @type {{ src: string, matrix: DOMMatrix }[]} */
  const images = []

  let scale = 1
  let currentImage = 0

  /**
   * @param {number} _scale
   */
  function setScale(_scale) {
  
    scale = _scale
  
    const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))
  
    const translateX = matrix.m41
    const translateY = matrix.m42
    
    // NOTE: scale is a bit off after multiplication
    const height = image.offsetHeight * scale
    const width = image.offsetWidth * scale
  
    const rangeY = Math.max(0, height - container.offsetHeight) / 2
    const rangeX = Math.max(0, width - container.offsetWidth) / 2
  
    image.style.transform = `matrix(${scale}, 0, 0, ${scale}, ${Math.max(Math.min(translateX, rangeX), -rangeX)}, ${Math.max(Math.min(translateY, rangeY), -rangeY)})`
  
  }
  
  /**
   * @param {number} translateX
   * @param {number} translateY
   */
  function setTransform(translateX, translateY) {
  
    const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))
  
    image.style.transform = `matrix(${matrix.a}, 0, 0, ${matrix.d}, ${translateX}, ${translateY})`
  
  }
  
  /**
   * @param {HTMLImageElement} image
   */
  function saveImage(image) {

    const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))
  
    currentImage = images.length
  
    images.push({ src: image.src, matrix })
  
  }
  
  function saveCurrentImage() {

    if (images.length < 1) return

    const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))
    images[currentImage] = { src: image.src, matrix }

  }

  /**
   * @param {number} index
   */
  function loadImage(index) {
  
    const { src, matrix } = images[index]
  
    currentImage = index
    scale = matrix.a
  
    image.style.transform = `matrix(${scale}, 0, 0, ${scale}, ${matrix.m41}, ${matrix.m42})`
    image.src = src
  
  }

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

  const container = applyGlobalStyles(document.createElement('div'))

  const header = applyGlobalStyles(document.createElement('header'))
  const imageRegion = applyGlobalStyles(document.createElement('div'))
  const image = applyGlobalStyles(document.createElement('img'))

  const ul = applyGlobalStyles(document.createElement('ul'))

  const rotateButton = applyGlobalStyles(document.createElement('li'))
  const deleteButton = applyGlobalStyles(document.createElement('li'))

  ul.style.display = 'flex'
  ul.style.listStyle = 'none'

  rotateButton.style.display = 'grid'
  rotateButton.style.placeItems = 'center'
  rotateButton.style.width = '40px'
  rotateButton.style.height = '40px'
  rotateButton.innerHTML = rotateSVG

  deleteButton.style.display = 'grid'
  deleteButton.style.placeItems = 'center'
  deleteButton.style.width = '40px'
  deleteButton.style.height = '40px'
  deleteButton.innerHTML = deleteSVG

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

  ul.appendChild(rotateButton)
  ul.appendChild(deleteButton)

  header.appendChild(ul)

  imageRegion.appendChild(image)

  container.appendChild(header)
  container.appendChild(imageRegion)

  container.ondrop = (event) => {

    event.preventDefault()

    for (const file of event.dataTransfer.files) {
      
      if (!file.type.startsWith('image/')) continue

      saveCurrentImage()

      image.src = URL.createObjectURL(file)

      setScale(1)
      saveImage(image)

    }

  }

  container.addEventListener('wheel', (event) => event.preventDefault())
  container.ondragover = ((event) => event.preventDefault())

  imageRegion.addEventListener('wheel', ({ deltaY }) => {

    event.preventDefault()

    scale += deltaY > 0 ? -(0.1 * scale) : (0.1 * scale)
    scale = Math.min(Math.max(scale, 1), 50)
  
    setScale(scale)

  })

  window.addEventListener('mousemove', ({ movementX, movementY, buttons }) => {

    if (buttons != 1) return

    const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))

    const translateX = matrix.m41
    const translateY = matrix.m42
  
    const { height, width } = image.getBoundingClientRect()
  
    const rangeY = Math.max(0, height - container.offsetHeight) / 2
    const rangeX = Math.max(0, width - container.offsetWidth) / 2
  
    setTransform(Math.max(Math.min(translateX + movementX, rangeX), -rangeX), Math.max(Math.min(translateY + movementY, rangeY), -rangeY))

  })

  window.addEventListener('keydown', (event) => {

    if (event.key == 'Insert') container.parentNode ? document.body.removeChild(container) : document.body.appendChild(container)

    if (!container.parentNode) return

    if (event.key == 'ArrowRight' && currentImage + 1 < images.length) {

      saveCurrentImage()
      
      currentImage++
  
      loadImage(currentImage)
  
    }
  
    if (event.key == 'ArrowLeft' && currentImage > 0) {
      
      saveCurrentImage()
  
      currentImage--
  
      loadImage(currentImage)
  
    }

  })

  deleteButton.onclick = () =>{

    if (images.length < 1) return

    if (images.length == 1) {

      images.pop()
      image.src = ''

      return

    }

    if (currentImage <= 0) {

      images.shift()
      loadImage(currentImage)

      return

    }

    images.splice(currentImage, 1)

    currentImage--
    loadImage(currentImage)

  }

  rotateButton.onclick = () => {

    if (images.length < 1) return

    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');

    canvas.width = image.naturalHeight;
    canvas.height = image.naturalWidth;

    ctx.rotate(Math.PI / 2);
    ctx.drawImage(image, 0, -canvas.width)

    canvas.toBlob((blob) => {

      image.src = URL.createObjectURL(blob)

      setScale(1)

    }, 'image/webp', 1)

  }

})()