let failedQueue = []

class HTTPStatusError extends Error {
  constructor(response, ...arg) {
    super(...arg)
    this.status = response.status
    this.headers = response.headers
  }
}

const processQueue = (error, token = null) => {
  failedQueue.forEach(prom => {
    if (error) {
      prom.reject(error)
    } else {
      prom.resolve(token)
    }
  })
  failedQueue = []
}

const loginScreen = document.getElementById("LoginScreen")

const openModal = function () {
  loginScreen.style.display = "block"
}

const closeModal = function () {
  loginScreen.style.display = ""
}

const loginForm = document.getElementById("LoginBasicForm")
const loginMsg = document.getElementById("LoginFormErrMsg")

const handleLoginSubmit = async function () {
  const res = await fetch('/login', { method: "POST", body: new FormData(loginForm) })
  if (res.ok) {
    appdata.user = document.getElementById("LoginFormUser").value
    closeModal()
    processQueue(null)
  } else {
    loginForm.reset()
    loginMsg.value = "Login failed."
    false
  }
}

document.getElementById("LoginSubmit").addEventListener("click", event => {
  event.preventDefault()
  event.stopPropagation()
  handleLoginSubmit()
})

const http = {
  get: async function (url, options = {}) {
    const res = await fetch(url)
    if (res.status == 401) {
      openModal()
      
      return new Promise((resolve, reject) => {
        failedQueue.push({resolve, reject})
      }).then(() => {
        return http.get(url)
      })
    } else if (res.ok) {
      const text = await res.text()
      console.log(text)
      if (res.status === 204 || !text) {
        // No content
        return null
      } else {
        if (options.disable_parse_json) {
          return text
        } else {
          try {
            return JSON.parse(text)
          } catch(e) {
            return text
          }
        }
      }
    } else {
      throw new HTTPStatusError(res, "HTTP returns error")
    }
  }
}

export {http}