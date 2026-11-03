require('dotenv').config();
const express = require('express');
const rateLimit = require('express-rate-limit');
const path = require('path');
const app = express();
app.disable('x-powered-by');
app.use(express.json({limit:'2kb'}));
app.use(express.static(path.join(__dirname,'public')));
const limiter = rateLimit({windowMs:60*1000,limit:10,standardHeaders:'draft-7',legacyHeaders:false});
const demo = [{anoFabricacao:2014,anoModelo:'2014',marca:'Ford',modelo:'Fiesta 1.0 8V Flex/Class 1.0 8V Flex 5p',codigoFipe:'003310-3',mesReferencia:'outubro de 2026',valor:31487,principal:true},{anoFabricacao:2014,anoModelo:'2014',marca:'Ford',modelo:'Fiesta S 1.0 8V Flex 5p',codigoFipe:'003380-4',mesReferencia:'outubro de 2026',valor:30149,principal:false},{anoFabricacao:2014,anoModelo:'2014',marca:'Ford',modelo:'Fiesta SE 1.0 8V Flex 5p',codigoFipe:'003381-2',mesReferencia:'outubro de 2026',valor:31855,principal:false}];
const clean = (item) => ({marca:item.marca??null,ano:item.anoModelo??item.anoFabricacao??null,modelo:item.modelo??null,codigoFipe:item.codigoFipe??null,valor:typeof item.valor==='number'?item.valor:null,mesReferencia:item.mesReferencia??null,principal:item.principal===true});
app.post('/api/consultar',limiter,async(req,res)=>{
 const placa=String(req.body?.placa??'').toUpperCase().replace(/[\s-]/g,'');
 if(!/^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$/.test(placa))return res.status(400).json({erro:'Informe uma placa válida com 7 caracteres.'});
 if(process.env.DEMO_MODE==='true')return res.json({placa,demonstracao:true,resultados:demo.map(clean)});
 if(!process.env.APIBRASIL_TOKEN)return res.status(503).json({erro:'Token da API não configurado no servidor.'});
 try{
  const response=await fetch('https://gateway.apibrasil.io/api/v2/consulta/veiculos/credits',{method:'POST',headers:{'Content-Type':'application/json','Authorization':`Bearer ${process.env.APIBRASIL_TOKEN}`},body:JSON.stringify({tipo:'fipe-chassi',placa,homolog:false}),signal:AbortSignal.timeout(120000)});
  const payload=await response.json();
  if(!response.ok||payload.error===true||payload.status_code>=400)return res.status(502).json({erro:'Não foi possível concluir a consulta. Verifique a placa ou tente novamente.'});
  const resultados=payload?.data?.resultados;
  if(!Array.isArray(resultados)||resultados.length===0)return res.status(404).json({erro:'Nenhum veículo encontrado para esta placa.'});
  return res.json({placa,demonstracao:false,resultados:resultados.map(clean)});
 }catch(e){return res.status(502).json({erro:'Falha de comunicação com o serviço de consulta.'});}
});
app.listen(Number(process.env.PORT)||3000,()=>console.log('Aplicação iniciada.'));
