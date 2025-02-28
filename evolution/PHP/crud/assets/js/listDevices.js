// configuração para requisição obter os devices
// informe o seu BearerToken
// não se esqueça de deixar a palavra Bearer antes do token

// VOCE DEVE SEMPRE COLOCAR AS SUAS CREDENCIAIS NO BACKEND!

const url = "https://gateway.apibrasil.io/api/v2";
const BearerToken = "Bearer 123"

const config = {
    url: `${url}/devices`,
    headers: { 
        'Authorization': `Bearer ${BearerToken}`,
    }
};

axios.request(config)
.then((response) => {

    // pega os dados da resposta
    const data = response.data;
    console.log('Lista de Devices', data);

    // preenche a tabela com os devices
    const table = document.querySelector('table tbody');

    // percorre os devices que foram retornados
    data.forEach((item, index) => {

        let qrcode = '';
        let reconnect = '';

        // verifica se é uma api do whatsapp 
        if ( typeof item?.server_limited?.type !== 'undefined' === true ) {
            qrcode = `<button class="btn btn-sm btn-success" onclick="qrCode('${item.device_token}', '${item.device_name}' )"><i class='bx bx-qr'></i></button>`;
            reconnect = `<button class="btn btn-sm btn-warning" onclick="reconnectDevice('${item.device_token}', '${item.device_name}' )"><i class='bx bx-refresh'></i></button>`;
        }



        const tr = document.createElement('tr');

        tr.innerHTML = `
            <th scope="row">${index + 1}</th>
            <td>${item?.device_name}</td>
            <td>${item?.service?.name}</td>
            <td>${item?.device_token}</td>
            <td>${item?.status}</td>
            <td>
                ${ qrcode }
                ${ reconnect }
                <button class="btn btn-sm btn-primary" onclick="showDevice('${item?.search}')" data-bs-toggle="modal" data-bs-target="#myModal"><i class='bx bx-show'></i></button>
                <button class="btn btn-sm btn-danger" onclick="deleteDevice('${item?.search}')"><i class='bx bx-trash'></i></button>
            </td>
        `;
        table.appendChild(tr);
    });

})
.catch((error) => {

    // possíveis códigos de erro
    // 401 Unauthorized
    // 500 Internal Server Error
    // 404 Not Found
    // 403 Forbidden
    // 400 Bad Request
    // 422 Unprocessable Entity
    // 429 Too Many Requests

    console.log(error);

    //escreve o erro em um alert na row
    const row = document.querySelector('.row');

    // cria um alerta
    const alert = document.createElement('div');
    alert.classList.add('alert', 'alert-danger');
    alert.innerHTML = `
        <h4 class="alert-heading">Erro ${error?.response?.status ?? ''}</h4>
        <p>${ JSON.stringify(error.response?.data) ?? ''}</p>
    `;
    row.appendChild(alert);

});

async function qrCode(device_token, device_name) {
 
    const myHeaders = new Headers();
    myHeaders.append("Content-Type", "application/json");
    myHeaders.append("DeviceToken", device_token);
    myHeaders.append("Authorization", `Bearer ${BearerToken}`);
    
    const body = JSON.stringify({
      "instanceName": `${device_name}`,
      "qrcode": true,
      "integration": "WHATSAPP-BAILEYS"
    });
    
    const requestOptions = {
      method: "POST",
      headers: myHeaders,
      body: body,
    };
    
    fetch(`${url}/evolution/instance/create`, requestOptions)
      .then((response) => response.text())
      .then((result) => {

        const data = JSON.parse(result);
        console.log(data);
        console.log(data?.response?.qrcode?.base64);
        console.log(data.message);
        
        //if error true
        if (data?.error === true) {

            document.querySelector('#qrcode').src = '';

            const qrcode = document.querySelector('#qrcode');
            qrcode.innerHTML = `
                <div class="alert alert-danger" role="alert">
                    ${data?.message}
                </div>
            `;

        }

        if (data?.error === false) {
            const qrcode = document.querySelector('#qrcode');
            qrcode.innerHTML = `
                <img src="${data?.response?.qrcode?.base64 ?? ''}" class="img-fluid" alt="QRCode" />
            `;
        }

        //modal show
        var myModal = new bootstrap.Modal(document.getElementById('myModal'), {
            keyboard: false
        });

        myModal.show();


      })
      .catch((error) => console.error(error));  
};

async function reconnectDevice (device_token, device_name) {
    
    const myHeaders = new Headers();
    myHeaders.append("Content-Type", "application/json");
    myHeaders.append("DeviceToken", device_token);
    myHeaders.append("Authorization", `Bearer ${BearerToken}`);
    
    const requestOptions = {
      method: "GET",
      headers: myHeaders,
    };
    
    fetch(`${url}/evolution/instance/connect`, requestOptions)
      .then((response) => response.text())
      .then((result) => {

        const data = JSON.parse(result);
        console.log(data);
        console.log(data?.response?.qrcode?.base64);
        console.log(data.message);
        
        if (data?.error === true) {
            
            document.querySelector('#qrcode').src = '';
            const qrcode = document.querySelector('#qrcode');
            qrcode.innerHTML = `
                <div class="alert alert-danger" role="alert">
                    ${data?.message}
                </div>
            `;
        }

        if (data?.error === false) {
            const qrcode = document.querySelector('#qrcode');
            qrcode.innerHTML = `
                <img src="${data?.response?.base64 ?? ''}" class="img-fluid" alt="QRCode" />
            `;
        }

        var myModal = new bootstrap.Modal(document.getElementById('myModal'), {
            keyboard: false
        });

        myModal.show();

      })
      .catch((error) => console.error(error));  

}