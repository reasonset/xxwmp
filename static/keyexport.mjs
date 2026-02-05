import {PubKeyAuth} from '/pubkeyauth.js'

const textarea = document.getElementById("Keystring")
textarea.addEventListener("click", async e => {
  await navigator.clipboard.writeText(textarea.value)
})
const pka = new PubKeyAuth()
const value = await pka.sign("")
textarea.value = value.publicKey
