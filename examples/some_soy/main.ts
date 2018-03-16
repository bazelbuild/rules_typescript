import {Template} from 'goog:some.templates';

const msg = Template({name:"World"}).getContent();
if (goog.isString(msg)){
    console.log(msg);
}
