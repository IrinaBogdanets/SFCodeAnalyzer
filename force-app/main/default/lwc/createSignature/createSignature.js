import { LightningElement,api } from 'lwc';
import saveSignature from '@salesforce/apex/ReportSignatureController.saveSignature';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import AgentTitleLabel from '@salesforce/label/c.CustomerServiceReportSignatureAgentTitle';
import CustomerTitleLabel from '@salesforce/label/c.CustomerServiceReportSignatureCustomerTitle';
import SaveLabel from '@salesforce/label/c.CustomerServiceReportSignatureSave';
import ClearLabel from '@salesforce/label/c.CustomerServiceReportSignatureClear';

let isMousePressed, 
    isDotFlag = false,
    prevX = 0,
    currX = 0,
    prevY = 0,
    currY = 0;            
       
let penColor = "#000000"; 
let lineWidth = 1.5;     

let canvasElement, ctx; 
let dataURL,convertedDataURI; //holds image data

export default class CreateSignature extends LightningElement {    
    @api record;
    @api description;
    fileName;
    @api headerText='To process with current application process, sign and upload it';

    get Title(){
        if(this.description == 'Agent Signature'){
            return AgentTitleLabel;
        } else {
            return CustomerTitleLabel;
        }
    }

    labels = {
        SaveLabel,
        ClearLabel
    };

    addEvents() {
        canvasElement.addEventListener('mousemove', this.handleMouseMove.bind(this));
        canvasElement.addEventListener('mousedown', this.handleMouseDown.bind(this));
        canvasElement.addEventListener('mouseup', this.handleMouseUp.bind(this));
        canvasElement.addEventListener('mouseout', this.handleMouseOut.bind(this));
        canvasElement.addEventListener("touchstart", this.handleTouchStart.bind(this));
        canvasElement.addEventListener("touchmove", this.handleTouchMove.bind(this));
        canvasElement.addEventListener("touchend", this.handleTouchEnd.bind(this));
    }

     handleMouseMove(event){
        if (isMousePressed) {
            this.setupCoordinate(event);
            this.redraw();
        }     
    }    
    handleMouseDown(event){
        event.preventDefault();
        this.setupCoordinate(event);           
        isMousePressed = true;
        isDotFlag = true;
        if (isDotFlag) {
            this.drawDot();
            isDotFlag = false;
        }     
    }    
    handleMouseUp(event){
        isMousePressed = false;      
    }
    handleMouseOut(event){
        isMousePressed = false;      
    }
    handleTouchStart(event) {
        if (event.targetTouches.length == 1) {
            this.setupCoordinate(event);     
        }
    };

    handleTouchMove(event) {
        // Prevent scrolling.
        event.preventDefault();
        this.setupCoordinate(event);
        this.redraw();
    };
    handleTouchEnd(event) {
        var wasCanvasTouched = event.target === canvasElement;
        if (wasCanvasTouched) {
            event.preventDefault();
            this.setupCoordinate(event);
            this.redraw();
        }
    };
    renderedCallback() {
        canvasElement = this.template.querySelector('canvas');
        ctx = canvasElement.getContext("2d");
        ctx.lineCap = 'round';
        this.addEvents();
     }
    signIt(e)
    {
        var signText = e.detail.value;
        this.fileName=signText;
        ctx.font = "30px GreatVibes-Regular";
        this.handleClearClick(e);
        ctx.fillText(signText, 30, canvasElement.height/2);
    }

    saveSignature(e)
    {
        dataURL = canvasElement.toDataURL("image/jpg");
        //convert that as base64 encoding
        convertedDataURI = dataURL.replace(/^data:image\/(png|jpg);base64,/, "");

        saveSignature({signElement: convertedDataURI,recId : this.record, signatureDescription: this.description})
        .then(result => {
            const signEvent = new CustomEvent("getsignedvalue", {
                detail: false
            });
            this.dispatchEvent(signEvent);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Signature Image saved in record',
                    variant: 'success',
                }),
            );
        })
        .catch(error => {
            //show error message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error uploading signature in Salesforce record',
                    message: error.body.message,
                    variant: 'error',
                }),
            );
        });
    }
    handleClearClick()
    {
        ctx.clearRect(0, 0, canvasElement.width, canvasElement.height);
    }

    setupCoordinate(eventParam){
        const clientRect = canvasElement.getBoundingClientRect();
        prevX = currX;
        prevY = currY;
        currX = eventParam.clientX -  clientRect.left;
        currY = eventParam.clientY - clientRect.top;
    }

    redraw() {
        ctx.beginPath();
        ctx.moveTo(prevX, prevY);
        ctx.lineTo(currX, currY);
        ctx.strokeStyle = penColor;
        ctx.lineWidth = lineWidth;        
        ctx.closePath(); 
        ctx.stroke(); 
    }
    drawDot(){
        ctx.beginPath();
        ctx.fillStyle = penColor;
        ctx.fillRect(currX, currY, lineWidth, lineWidth); 
        ctx.closePath();
    }
}