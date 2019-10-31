import { LightningElement, track, api } from 'lwc';
import getBatchFields from '@salesforce/apex/GE_TemplateBuilderCtrl.getBatchFields';
import { findIndexByProperty, shiftToIndex, mutable, sort } from 'c/utilTemplateBuilder';

const REQUIRED_FIELDS = [
    'Name'
];
Object.freeze(REQUIRED_FIELDS);

export default class geTemplateBuilderBatchHeader extends LightningElement {
    @track isLoading = true;
    @track batchFields;
    @track selectedBatchFields;
    /* Public setter for the tracked property selectedBatchFields */
    // TODO: Needs to be revisited, WIP tied to retrieving and rendering an existing template
    @api
    set selectedBatchFields(selectedBatchFields) {
        this.selectedBatchFields = selectedBatchFields;
    }

    connectedCallback() {
        this.init();
    }

    @api
    init = async () => {
        this.isLoading = true;
        this.batchFields = await getBatchFields();
        this.batchFields = sort(this.batchFields, 'label', 'asc');
        this.handleRequiredFields();
        this.toggleCheckboxForSelectedBatchFields();
        this.isLoading = false;
    }

    /*******************************************************************************
    * @description Public method that returns a list of batch header field instances
    * of the BatchHeaderField class. Called when saving a form template.
    *
    * @return {list} batchHeaderFields: List of batch header field instances of the
    * BatchHeaderField class.
    */
    @api
    getTabData() {
        const selectedBatchFieldValues = this.template.querySelectorAll('c-ge-template-builder-form-field');

        let batchHeaderFields = [];

        for (let i = 0; i < selectedBatchFieldValues.length; i++) {
            let batchField = selectedBatchFieldValues[i].getFormFieldValues();
            batchHeaderFields.push(batchField);
        }

        return batchHeaderFields;
    }

    /*******************************************************************************
    * @description Sends an event up to geTemplateBuilder for tab navigation
    *
    * @param {object} event: Onclick event object from lightning-button
    */
    handleGoToTab(event) {
        let detail = {
            tabValue: event.target.getAttribute('data-tab-value')
        }
        this.dispatchEvent(new CustomEvent('gototab', { detail: detail }));
    }

    /*******************************************************************************
    * @description Onchange event handler for the batch header field checkboxes.
    * Adds BatchHeaderField objects to the selectedBatchFields array.
    * selectedBatchFields is used in the UI to render instances of the
    * geTemplateBuilderFormField component.
    *
    * @param {object} event: Onchange event object from lightning-input checkbox
    */
    handleToggleBatchField(event) {
        const fieldName = event.target.value;
        const index = findIndexByProperty(this.selectedBatchFields, 'value', fieldName);
        const addSelectedField = index === -1 ? true : false;

        if (addSelectedField) {
            this.addField(fieldName);
        } else {
            this.removeField(index);
        }
    }

    /*******************************************************************************
    * @description Adds a field to the selected fields
    *
    * @param {object} target: Object containing the label and value of the field
    * to be added
    */
    addField(fieldName) {
        let batchField = this.batchFields.find(bf => {
            return bf.value === fieldName;
        });

        let field = {
            label: batchField.label,
            value: batchField.value,
            required: batchField.isRequired,
            isRequiredFieldDisabled: batchField.isRequiredFieldDisabled,
            allowDefaultValue: false,
            defaultValue: null,
            dataType: batchField.dataType,
            picklistOptions: batchField.picklistOptions
        };

        if (!this.selectedBatchFields) { this.selectedBatchFields = [] }
        this.selectedBatchFields = [...this.selectedBatchFields, field];
    }

    /*******************************************************************************
    * @description Removes a field from the selected fields by index
    *
    * @param {integer} index: Index of the field to be removed
    */
    removeField(index) {
        this.selectedBatchFields = this.getTabData();
        let selectedBatchFields = mutable(this.selectedBatchFields);
        selectedBatchFields.splice(index, 1);
        this.selectedBatchFields = selectedBatchFields;
    }

    /*******************************************************************************
    * @description Handles shifting the BatchHeaderField element up in the list and UI
    *
    * @param {object} event: Onclick event object from lightning-button
    */
    handleFormFieldUp(event) {
        this.selectedBatchFields = this.getTabData();
        let oldIndex = findIndexByProperty(this.selectedBatchFields, 'value', event.detail.value);
        if (oldIndex > 0) {
            this.selectedBatchFields = shiftToIndex(mutable(this.selectedBatchFields), oldIndex, oldIndex - 1);
        }
    }

    /*******************************************************************************
    * @description Handles shifting the BatchHeaderField element down in the list and UI
    *
    * @param {object} event: Onclick event object from lightning-button
    */
    handleFormFieldDown(event) {
        this.selectedBatchFields = this.getTabData();
        let oldIndex = findIndexByProperty(this.selectedBatchFields, 'value', event.detail.value);
        if (oldIndex < this.selectedBatchFields.length - 1) {
            this.selectedBatchFields = shiftToIndex(mutable(this.selectedBatchFields), oldIndex, oldIndex + 1);
        }
    }

    // TODO: Needs to be cleaned up/reevaluated
    /*******************************************************************************
    * @description WIP. Function adds required fields to selectedBatchFields property
    */
    handleRequiredFields() {
        for (let i = 0; i < this.batchFields.length; i++) {
            if (REQUIRED_FIELDS.includes(this.batchFields[i].value)) {
                this.batchFields[i].isRequired = true;
                this.batchFields[i].isRequiredFieldDisabled = true;
            }
        }

        const requiredFields = this.batchFields.filter(batchField => { return batchField.isRequired });

        const selectedFieldsExists = this.selectedBatchFields && this.selectedBatchFields.length > 0;

        requiredFields.forEach((field) => {
            if (selectedFieldsExists) {
                const alreadySelected = this.batchFields.find(bf => { return bf.value === field.value; });
                if (alreadySelected) { return; }
            }

            this.addField(field.value);
        });
    }

    // TODO: Need to finish or scrap the incomplete function below
    /*******************************************************************************
    * @description WIP. Function toggles the checkboxes for any existing/selected batch
    * header fields. Used when retrieving an existing form template.
    */
    toggleCheckboxForSelectedBatchFields() {
        if (this.selectedBatchFields && this.selectedBatchFields.length > 0) {
            let _batchFields = mutable(this.batchFields);

            for (let i = 0; i < this.selectedBatchFields.length; i++) {
                const selectedBatchField = this.selectedBatchFields[i];
                const batchFieldIndex = findIndexByProperty(
                    _batchFields,
                    'value',
                    selectedBatchField.value);

                _batchFields[batchFieldIndex].checked = true;
            }

            this.batchFields = _batchFields;
        }
    }
}