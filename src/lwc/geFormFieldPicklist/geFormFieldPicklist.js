import { LightningElement, api, track, wire } from 'lwc';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';

export default class GeFormFieldPicklist extends LightningElement {
    @api objectName;
    @api fieldName;
    @api label;
    @api variant;
    @api required;
    @api value;
    @api objectDescribeInfo;
    @api className;

    @track picklistValues;

    @wire(getPicklistValues, {
        fieldApiName: '$fullFieldApiName',
        recordTypeId: '$objectDescribeInfo.defaultRecordTypeId' })
    wiredPicklistValues({error, data}) {
        if(data) {
            this.picklistValues = data.values;
        }

        if(error) {
            console.error(error);
        }
    }

    get fullFieldApiName() {
        return `${this.objectName}.${this.fieldName}`;
    }

    handleValueChange(event) {
        this.value = event.detail.value;
        this.dispatchEvent(new CustomEvent('onchange', event)); // bubble up to ge-form-field
    }

    @api
    reportValidity(){
        const picklistField = this.template.querySelector('lightning-combobox');
        return picklistField.reportValidity();
    }

    @api
    checkValidity(){
        const picklistField = this.template.querySelector('lightning-combobox');
        return picklistField.checkValidity();
    }

}