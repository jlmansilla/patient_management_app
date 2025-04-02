import { Controller } from "@hotwired/stimulus"

// Se conecta a data-controller="hello"
export default class extends Controller {
  // Targets: data-hello-target="output"
  static targets = [ "output", "nameInput" ]
  // Values: data-hello-greeting-value="Hola"
  static values = { greeting: String }

  connect() {
    console.log("¡Controlador Hello conectado!", this.element);
    // Establece el texto inicial si hay un valor 'greeting'
    if (this.hasGreetingValue) {
      this.outputTarget.textContent = `${this.greetingValue}, Stimulus!`
    } else {
      this.outputTarget.textContent = "¡Hola, Stimulus!";
    }
  }

  greet() {
    const name = this.nameInputTarget.value || "Mundo";
    const greeting = this.hasGreetingValue ? this.greetingValue : "Hola";
    console.log(`${greeting}, ${name}!`);
    this.outputTarget.textContent = `${greeting}, ${name}!`;
  }

  // Ejemplo de uso en una vista ERB:
  /*
  <div data-controller="hello" data-hello-greeting-value="Bienvenido">
    <input type="text" data-hello-target="nameInput" class="border rounded p-2">
    <button data-action="click->hello#greet" class="bg-blue-500 text-white p-2 rounded">
      Saludar
    </button>
    <span data-hello-target="output" class="ml-2"></span>
  </div>
  */
}
