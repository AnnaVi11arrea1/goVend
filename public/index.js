document.addEventListener("DOMContentLoaded", () => {
    
    function addEventListenersToButtons() {
        document.querySelectorAll('.add-to-list').forEach(button => {
            button.addEventListener('click', function() {
                let listItem = this.previousElementSibling;
                if (listItem.checked) {
                        const placeitem = document.getElementById('selected-list')
                        const listaf = document.createElement("li");
                        const nodeaf = document.createTextNode(this.parentElement.innerText.trim());
                        listaf.appendChild(nodeaf);
                        placeitem.appendChild(listaf);

                }
            });
        });
    }

    // Add event listeners to buttons on page load
    addEventListenersToButtons();

    document.getElementById('input-box').addEventListener('keypress', function (e) {
        if (e.key === 'Enter') {
            let userMessage = e.target.value;
            e.target.value = ''; // Clear input box

            let chatBox = document.getElementById('chat-box');
            chatBox.innerHTML += `<p class="chat"><strong>You:</strong> ${userMessage}</p>`;
        
            let eventSource = new EventSource(`/chat?message=${encodeURIComponent(userMessage)}`);

            eventSource.onmessage = function(event) {
                console.log('Message:', event.data);
                chatBox.innerHTML += `<p class="chat"><strong>goVend:</strong> ${event.data}</p>`;
                chatBox.scrollTop = chatBox.scrollHeight; // Auto-scroll to the bottom
                
               // Add event listeners to the new buttons
               addEventListenersToButtons();
                   
            };
           
              eventSource.onerror = function () {
                eventSource.close();
            };
        }
    });
});
